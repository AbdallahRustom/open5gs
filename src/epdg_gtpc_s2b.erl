% S2b: GTPv2C towards PGW
%
% 3GPP TS 29.274
%
% (C) 2023 by sysmocom - s.f.m.c. GmbH <info@sysmocom.de>
% Author: Pau Espin Pedrol <pespin@sysmocom.de>
%
% All Rights Reserved
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU Affero General Public License as
% published by the Free Software Foundation; either version 3 of the
% License, or (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU Affero General Public License
% along with this program.  If not, see <http://www.gnu.org/licenses/>.
%
% Additional Permission under GNU AGPL version 3 section 7:
%
% If you modify this Program, or any covered work, by linking or
% combining it with runtime libraries of Erlang/OTP as released by
% Ericsson on http://www.erlang.org (or a modified version of these
% libraries), containing parts covered by the terms of the Erlang Public
% License (http://www.erlang.org/EPLICENSE), the licensors of this
% Program grant you additional permission to convey the resulting work
% without the need to license the runtime libraries of Erlang/OTP under
% the GNU Affero General Public License. Corresponding Source for a
% non-source form of such a combination shall include the source code
% for the parts of the runtime libraries of Erlang/OTP used as well as
% that of the covered work.


-module(epdg_gtpc_s2b).
-author('Pau Espin Pedrol <pespin@sysmocom.de>').

-behaviour(gen_server).

-include_lib("gtplib/include/gtp_packet.hrl").

%% API Function Exports
-export([start_link/5]).
-export([terminate/2]).
%% gen_server Function Exports
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).
-export([code_change/3]).
-export([create_session_req/1, delete_session_req/1]).

%% Application Definitions
-define(SERVER, ?MODULE).
-define(SVC_NAME, ?MODULE).
-define(APP_ALIAS, ?MODULE).
-define(CALLBACK_MOD, epdg_gtpc_s2b_cb).
-define(ENV_APP_NAME, osmo_epdg).

%% TODO: make APN configurable? get it from HSS?
-define(APN, <<"internet">>).
-define(MCC, 901).
-define(MNC, 42).
-define(MNC_SIZE, 3).

-record(gtp_state, {
        socket,
        laddr_str,
        laddr           :: inet:ip_address(),
        lport           :: non_neg_integer(),
        raddr_str,
        raddr           :: inet:ip_address(),
        rport           :: non_neg_integer(),
        restart_counter :: 0..255,
        seq_no          :: 0..16#ffffffff,
        next_local_control_tei = 1 :: 0..16#ffffffff,
        next_local_data_tei = 1 :: 0..16#ffffffff,
        sessions = sets:new()
}).

-record(gtp_bearer, {
    ebi                   :: non_neg_integer(),
    local_data_tei = 0    :: non_neg_integer(),
    remote_data_tei = 0    :: non_neg_integer()
}).

-record(gtp_session, {
    imsi                   :: binary(),
    pid                    :: pid(),
    apn                    :: binary(),
    ue_ip                  :: inet:ip_address(),
    local_control_tei = 0  :: non_neg_integer(),
    remote_control_tei = 0 :: non_neg_integer(),
    bearer                 :: gtp_bearer %% FIXME: only one bearer for now
}).

start_link(LocalAddr, LocalPort, RemoteAddr, RemotePort, Options) ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [LocalAddr, LocalPort, RemoteAddr, RemotePort, Options], []).

peer_down(API, SvcName, {PeerRef, _} = Peer) ->
    % fixme: why do we still have ets here?
    (catch ets:delete(?MODULE, {API, PeerRef})),
    gen_server:cast(?SERVER, {peer_down, SvcName, Peer}),
    ok.

init(State) ->
    lager:info("epdg_gtpc_s2b: init(): ~p", [State]),
    [LocalAddr | [LocalPort | [RemoteAddr | [RemotePort | _]]]] = State,
    lager:info("epdg_gtpc_s2b: Binding to IP ~s port ~p~n", [LocalAddr, LocalPort]),
    {ok, LocalAddrInet} = inet_parse:address(LocalAddr),
    {ok, RemoteAddrInet} = inet_parse:address(RemoteAddr),
    Opts = [
        binary,
        {ip, LocalAddrInet},
        {active, true},
        {reuseaddr, true}
    ],
    Ret = gen_udp:open(LocalPort, Opts),
    case Ret of
        {ok, Socket} ->
            lager:info("epdg_gtpc_s2b: Socket is ~p~n", [Socket]),
            ok = connect({Socket, RemoteAddr, RemotePort}),
            St = #gtp_state{
                    socket = Socket,
                    laddr_str = LocalAddr,
                    laddr = LocalAddrInet,
                    lport = LocalPort,
                    raddr_str = RemoteAddr,
                    raddr = RemoteAddrInet,
                    rport = RemotePort,
                    restart_counter = 0,
                    seq_no = 0
                },
            {ok, St};
        {error, Reason} ->
            lager:error("GTPv2C UDP socket open error: ~w~n", [Reason])
    end.

create_session_req(Imsi) ->
    gen_server:call(?SERVER, {gtpc_create_session_req, {Imsi}}).

delete_session_req(Imsi) ->
    gen_server:call(?SERVER, {gtpc_delete_session_req, {Imsi}}).

handle_call({gtpc_create_session_req, {Imsi}}, {Pid, _Tag} = _From, State0) ->
    {Sess0, State1} = find_or_new_gtp_session(Imsi, Pid, State0),
    Req = gen_create_session_request(Sess0, State1),
    %TODO: increment State.seq_no.
    tx_gtp(Req, State1),
    lager:debug("Waiting for CreateSessionResponse~n", []),
    {reply, ok, State1};

handle_call({gtpc_delete_session_req, {Imsi}}, _From, State) ->
    Sess = find_gtp_session_by_imsi(Imsi, State),
    case Sess of
        #gtp_session{imsi = Imsi} ->
            Req = gen_delete_session_request(Sess, State),
            %TODO: increment State.seq_no.
            tx_gtp(Req, State),
            {reply, ok, State};
        undefined ->
            {reply, {error, imsi_unknown}, State}
    end.

%% @callback gen_server
handle_cast(stop, State) ->
    {stop, normal, State};
handle_cast(Req, State) ->
    lager:info("S2b handle_cast: ~p ~n", [Req]),
    {noreply, State}.

%% @callback gen_server
handle_info({udp, _Socket, IP, InPortNo, RxMsg}, State) ->
    lager:info("S2b: Rx from IP ~p port ~p: ~p~n", [IP, InPortNo, RxMsg]),
    Req = gtp_packet:decode(RxMsg),
    lager:info("S2b: Rx from IP ~p port ~p: ~p~n", [IP, InPortNo, Req]),
    rx_gtp(Req, State);
handle_info(Info, State) ->
    lager:info("S2b handle_info: ~p ~n", [Info]),
    {noreply, State}.

%% @callback gen_server
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% @callback gen_server
terminate(normal, State) ->
    udp_gen:close(State#gtp_state.socket),
    ok;
terminate(shutdown, _State) ->
    ok;
terminate({shutdown, _Reason}, _State) ->
    ok;
terminate(_Reason, _State) ->
    ok.

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

new_gtp_session(Imsi, Pid, State) ->
    % TODO: find non-used local TEI inside State
    Bearer = #gtp_bearer{
        ebi = 5,
        local_data_tei = State#gtp_state.next_local_data_tei
    },
    Sess = #gtp_session{imsi = Imsi,
        pid = Pid,
        apn = ?APN,
        local_control_tei = State#gtp_state.next_local_control_tei,
        bearer = Bearer
    },
    NewSt = State#gtp_state{next_local_control_tei = State#gtp_state.next_local_control_tei + 1,
                            next_local_data_tei = State#gtp_state.next_local_data_tei + 1,
                            sessions = sets:add_element(Sess, State#gtp_state.sessions)},
    {Sess, NewSt}.

% returns Sess if found, undefined it not
find_gtp_session_by_imsi(Imsi, State) ->
    sets:fold(
        fun(SessIt = #gtp_session{imsi = Imsi}, _AccIn) -> SessIt;
           (_, AccIn) -> AccIn
        end,
        undefined,
        State#gtp_state.sessions).

find_or_new_gtp_session(Imsi, Pid, State) ->
    Sess = find_gtp_session_by_imsi(Imsi, State),
    case Sess of
        #gtp_session{imsi = Imsi} ->
            {Sess, State};
        undefined ->
            new_gtp_session(Imsi, Pid, State)
    end.

update_gtp_session(OldSess, NewSess, State) ->
    SetRemoved = sets:del_element(OldSess, State#gtp_state.sessions),
    SetUpdated = sets:add_element(NewSess, SetRemoved),
    State#gtp_state{sessions = SetUpdated}.

delete_gtp_session(Sess, State) ->
    SetRemoved = sets:del_element(Sess, State#gtp_state.sessions),
    State#gtp_state{sessions = SetRemoved}.

update_gtp_session_from_create_session_response_ie(none, Sess) ->
    Sess;
update_gtp_session_from_create_session_response_ie({_,
                                                    #v2_fully_qualified_tunnel_endpoint_identifier{
                                                        interface_type = _Interface,
                                                        key = TEI, ipv4 = _IP4, ipv6 = _IP6},
                                                    Next}, Sess) ->
    update_gtp_session_from_create_session_response_ie(maps:next(Next), Sess#gtp_session{remote_control_tei = TEI});
update_gtp_session_from_create_session_response_ie({_, _, Next},
                                                   Sess) ->
    update_gtp_session_from_create_session_response_ie(maps:next(Next), Sess).

update_gtp_session_from_create_session_response_ies(#gtp{ie = IEs}, Sess) ->
    update_gtp_session_from_create_session_response_ie(maps:next(maps:iterator(IEs)), Sess).

update_gtp_session_from_create_session_response(Resp = #gtp{version = v2, type = create_session_response}, Sess) ->
    update_gtp_session_from_create_session_response_ies(#gtp{ie = Resp#gtp.ie}, Sess).

% returns Sess if found, undefined it not
find_gtp_session_by_local_teic(LocalControlTei, State) ->
    sets:fold(
        fun(SessIt = #gtp_session{local_control_tei = LocalControlTei}, _AccIn) -> SessIt;
            (_, AccIn) -> AccIn
        end,
        undefined,
        State#gtp_state.sessions).

%% connect/2
connect(Name, {Socket, RemoteAddr, RemotePort}) ->
    lager:info("~s connecting to IP ~s port ~p~n", [Name, RemoteAddr, RemotePort]),
    gen_udp:connect(Socket, RemoteAddr, RemotePort).

connect(Address) ->
    connect(?SVC_NAME, Address).

rx_gtp(Resp = #gtp{version = v2, type = create_session_response}, State0) ->
    Sess0 = find_gtp_session_by_local_teic(Resp#gtp.tei, State0),
    case Sess0 of
        undefined ->
            lager:error("Rx unknown TEI ~p: ~p~n", [Resp#gtp.tei, Resp]),
            {noreply, State0};
        Sess0 ->
            Sess1 = update_gtp_session_from_create_session_response(Resp, Sess0),
            lager:info("s2b: Updated Session after create_session_response: ~p~n", [Sess1]),
            State1 = update_gtp_session(Sess0, Sess1, State0),
            epdg_ue_fsm:received_gtpc_create_session_response(Sess0#gtp_session.pid, {ok, Resp}),
            {noreply, State1}
        end;

rx_gtp(Resp = #gtp{version = v2, type = delete_session_response}, State0) ->
    Sess = find_gtp_session_by_local_teic(Resp#gtp.tei, State0),
    case Sess of
        undefined ->
            lager:error("Rx unknown TEI ~p: ~p~n", [Resp#gtp.tei, Resp]),
            {noreply, State0};
        Sess ->
            State1 = delete_gtp_session(Sess, State0),
            epdg_ue_fsm:received_gtpc_delete_session_response(Sess#gtp_session.pid, Resp),
            {noreply, State1}
        end;

rx_gtp(Req = #gtp{version = v2, type = delete_bearer_request}, State) ->
    Sess = find_gtp_session_by_local_teic(Req#gtp.tei, State),
    case Sess of
        undefined ->
            lager:error("Rx unknown TEI ~p: ~p~n", [Req#gtp.tei, Req]),
            {noreply, State};
        Sess ->
            Resp = gen_delete_bearer_response(Req, Sess, request_accepted, State),
            tx_gtp(Resp, State),
            State1 = delete_gtp_session(Sess, State),
            {noreply, State1}
        end;

rx_gtp(Req, State) ->
    lager:error("S2b: UNIMPLEMENTED Rx: ~p~n", [Req]),
    {noreply, State}.

tx_gtp(Req, State) ->
    lager:info("s2b: Tx ~p~n", [Req]),
    Msg = gtp_packet:encode(Req),
    gen_udp:send(State#gtp_state.socket, State#gtp_state.raddr, State#gtp_state.rport, Msg).

%% 7.2.1 Create Session Request
gen_create_session_request(#gtp_session{imsi = Imsi,
                                    apn = Apn,
                                    local_control_tei = LocalCtlTEI,
                                    bearer = Bearer},
                           #gtp_state{laddr = LocalAddr,
                                      restart_counter = RCnt,
                                      seq_no = SeqNo}) ->
    BearersIE = [#v2_bearer_level_quality_of_service{
                    pci = 1, pl = 10, pvi = 0, label = 8,
                    maximum_bit_rate_for_uplink      = 0,
                    maximum_bit_rate_for_downlink    = 0,
                    guaranteed_bit_rate_for_uplink   = 0,
                    guaranteed_bit_rate_for_downlink = 0
                  },
                  #v2_eps_bearer_id{eps_bearer_id = Bearer#gtp_bearer.ebi},
                  #v2_fully_qualified_tunnel_endpoint_identifier{
                    instance = 0,
                    interface_type = 31, %% "S2b-U ePDG GTP-U"
                    key = Bearer#gtp_bearer.local_data_tei,
                    ipv4 = gtp_utils:ip_to_bin(LocalAddr)
                  }
                ],
    IEs = [#v2_recovery{restart_counter = RCnt},
           #v2_international_mobile_subscriber_identity{imsi = Imsi},
           #v2_rat_type{rat_type = 3}, %% 3 = WLAN
           #v2_fully_qualified_tunnel_endpoint_identifier{
                instance = Bearer#gtp_bearer.ebi,
                interface_type = 30, %% "S2b ePDG GTP-C"
                key = LocalCtlTEI,
                ipv4 = gtp_utils:ip_to_bin(LocalAddr)
            },
            #v2_access_point_name{instance = 0, apn = [Apn]},
            #v2_selection_mode{mode = 0},
            #v2_pdn_address_allocation{type = ipv4, address = <<0,0,0,0>>},
            #v2_bearer_context{group = BearersIE},
            #v2_serving_network{
                    plmn_id = gtp_utils:plmn_to_bin(?MCC, ?MNC, ?MNC_SIZE)
            }
          ],
    #gtp{version = v2, type = create_session_request, tei = 0, seq_no = SeqNo, ie = IEs}.

%% 7.2.9 Delete Session Request
gen_delete_session_request(#gtp_session{remote_control_tei = RemoteCtlTEI,
                                        bearer = Bearer},
                           #gtp_state{laddr = LocalAddr,
                                      seq_no = SeqNo}) ->
    IEs = [#v2_eps_bearer_id{eps_bearer_id = Bearer#gtp_bearer.ebi},
           #v2_fully_qualified_tunnel_endpoint_identifier{
               instance = Bearer#gtp_bearer.ebi,
               interface_type = 30, %% "S2b ePDG GTP-C"
               key = Bearer#gtp_bearer.local_data_tei,
               ipv4 = gtp_utils:ip_to_bin(LocalAddr)
           }
    ],
    #gtp{version = v2, type = delete_session_request, tei = RemoteCtlTEI, seq_no = SeqNo, ie = IEs}.


gen_delete_bearer_response(Req = #gtp{version = v2, type = delete_bearer_request},
                           Sess = #gtp_session{remote_control_tei = RemoteCtlTEI},
                           GtpCause,
                           #gtp_state{restart_counter = RCnt}) ->
    IEs = [#v2_recovery{restart_counter = RCnt},
           #v2_cause{v2_cause = GtpCause}
          ],
    #gtp{version = v2,
         type = delete_bearer_response,
         tei = RemoteCtlTEI,
         seq_no = Req#gtp.seq_no,
         ie = IEs}.
