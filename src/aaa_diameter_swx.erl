% SWx: AAA side
%
% TS 29.273
%
% (C) 2023 by sysmocom - s.f.m.c. GmbH <info@sysmocom.de>
% Author: Alexander Couzens <lynxis@fe80.eu>
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
% along with this program.  If not, see <https://www.gnu.org/licenses/>.
%
% Additional Permission under GNU AGPL version 3 section 7:
%
% If you modify this Program, or any covered work, by linking or
% combining it with runtime libraries of Erlang/OTP as released by
% Ericsson on https://www.erlang.org (or a modified version of these
% libraries), containing parts covered by the terms of the Erlang Public
% License (https://www.erlang.org/EPLICENSE), the licensors of this
% Program grant you additional permission to convey the resulting work
% without the need to license the runtime libraries of Erlang/OTP under
% the GNU Affero General Public License. Corresponding Source for a
% non-source form of such a combination shall include the source code
% for the parts of the runtime libraries of Erlang/OTP used as well as
% that of the covered work.


-module(aaa_diameter_swx).
-author('Alexander Couzens <lynxis@fe80.eu>').

-behaviour(gen_server).

-include_lib("diameter_3gpp_ts29_273_swx.hrl").
-include_lib("diameter/include/diameter_gen_base_rfc6733.hrl").
-include("gtp_utils.hrl").

%% API Function Exports
-export([start_link/0]).
-export([start/0, stop/0, terminate/2]).
%% gen_server Function Exports
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).
-export([code_change/3]).
-export([multimedia_auth_request/6]).
-export([server_assignment_request/4]).
-export([test/0, test/1]).

%% Diameter Application Definitions
-define(SERVER, ?MODULE).
-define(SVC_NAME, ?MODULE).
-define(APP_ALIAS, ?MODULE).
-define(CALLBACK_MOD, aaa_diameter_swx_cb).
-define(DIAMETER_DICT_SWX, diameter_3gpp_ts29_273_swx).
-define(ENV_APP_NAME, osmo_epdg).
-define(ENV_DEFAULT_SESSION_ID, "epdg@localdomain").
-define(ENV_DEFAULT_ORIG_REALM, "localdomain").
-define(ENV_DEFAULT_ORIG_HOST, "epdg.localdomain").
-define(ENV_DEFAULT_VENDOR_ID, 0).
-define(ENV_DEFAULT_DIAMETER_PROTO, sctp).
-define(ENV_DEFAULT_DIAMETER_REMOTE_IP, "127.0.0.1").
-define(ENV_DEFAULT_DIAMETER_REMOTE_PORT, 3868).
-define(ENV_DEFAULT_DIAMETER_CONNECT_TIMER_MS, 30000).
-define(ENV_DEFAULT_DIAMETER_WATCHDOG_TIMER_MS, 30000).
-define(ENV_DEFAULT_DIAMETER_WATCHDOG_CFG, [{okay, 3}, {suspect, 1}]).
-define(ENV_DEFAULT_DIAMETER_TRANSMIT_TIMER_MS, 10000).

-define(VENDOR_ID_3GPP, 10415).
-define(VENDOR_ID_3GPP2, 5535).
-define(VENDOR_ID_ETSI, 13019).
-define(DIAMETER_APP_ID_SWX, ?DIAMETER_DICT_SWX:id()).
%% The service configuration. As in the server example, a client
%% supporting multiple Diameter applications may or may not want to
%% configure a common callback module on all applications.
-define(SERVICE,
        [{'Origin-Host', application:get_env(?ENV_APP_NAME, dia_swx_origin_host, ?ENV_DEFAULT_ORIG_HOST)},
         {'Origin-Realm', application:get_env(?ENV_APP_NAME, dia_swx_origin_realm, ?ENV_DEFAULT_ORIG_REALM)},
         {'Vendor-Id', application:get_env(?ENV_APP_NAME, dia_swx_vendor_id, ?ENV_DEFAULT_VENDOR_ID)},
         {'Vendor-Specific-Application-Id',
                [#'diameter_base_Vendor-Specific-Application-Id'{
                 'Vendor-Id'           = ?VENDOR_ID_3GPP,
                 'Auth-Application-Id' = [?DIAMETER_APP_ID_SWX]}]},
         {'Product-Name', "osmo-epdg"},
         % TODO: check which we should annouce here as Supported-Vendor-Id
         {'Supported-Vendor-Id', [?VENDOR_ID_3GPP, ?VENDOR_ID_ETSI, ?VENDOR_ID_3GPP2]},
         { application,
          [{alias, ?APP_ALIAS},
           {dictionary, ?DIAMETER_DICT_SWX},
           {module, ?CALLBACK_MOD},
           {answer_errors, callback}]}]).

-record(swx_state, {
        tx_timeout :: non_neg_integer(),
        handlers,
        peers = #{}
}).

%% @doc starts gen_server implementation process
-spec start() -> ok | {error, term()}.
start() ->
    application:ensure_all_started(?MODULE),
    start_link().

%% @doc stops gen_server implementation process
-spec stop() -> ok.
stop() ->
    gen_server:cast(?SERVER, stop).

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

peer_down(API, SvcName, {PeerRef, _} = Peer) ->
    % fixme: why do we still have ets here?
    (catch ets:delete(?MODULE, {API, PeerRef})),
    gen_server:cast(?SERVER, {peer_down, SvcName, Peer}),
    ok.

init([]) ->
    Proto = application:get_env(?ENV_APP_NAME, dia_swx_proto, ?ENV_DEFAULT_DIAMETER_PROTO),
    Ip = application:get_env(?ENV_APP_NAME, dia_swx_remote_ip, ?ENV_DEFAULT_DIAMETER_REMOTE_IP),
    Port = application:get_env(?ENV_APP_NAME, dia_swx_remote_port, ?ENV_DEFAULT_DIAMETER_REMOTE_PORT),
    ConnectTimer = application:get_env(?ENV_APP_NAME, dia_swx_connect_timer, ?ENV_DEFAULT_DIAMETER_CONNECT_TIMER_MS),
    WatchdogTimer = application:get_env(?ENV_APP_NAME, dia_swx_watchdog_timer, ?ENV_DEFAULT_DIAMETER_WATCHDOG_TIMER_MS),
    WatchdogConfig = application:get_env(?ENV_APP_NAME, dia_swx_watchdog_config, ?ENV_DEFAULT_DIAMETER_WATCHDOG_CFG),
    TxTimer = application:get_env(?ENV_APP_NAME, dia_swx_transmit_timer, ?ENV_DEFAULT_DIAMETER_TRANSMIT_TIMER_MS),
    ok = diameter:start_service(?MODULE, ?SERVICE),
    % lager:info("DiaServices is ~p~n", [DiaServ]),
    {ok, _} = connect({address, Proto, Ip, Port}, {timer, ConnectTimer, WatchdogTimer, WatchdogConfig}),
    {ok, #swx_state{tx_timeout = TxTimer}}.

test() ->
    test("001011234567890").

test(IMSI) ->
    multimedia_auth_request(IMSI, 1, 3, "EAP-AKA", 33, []).

multimedia_auth_request(IMSI, RAT, NumAuthItems, AuthScheme, PdpTypeNr, AuthorizationOpt) ->
    gen_server:call(?SERVER,
                          {mar, {IMSI, RAT, NumAuthItems, AuthScheme, PdpTypeNr, AuthorizationOpt}}).
% APN is optional and should be []
server_assignment_request(IMSI, Type, APN, AgentInfoOpt) ->
    gen_server:call(?SERVER,
                          {sar, {IMSI, Type, APN, AgentInfoOpt}}).

result_code_success(2001) -> ok;
result_code_success(2002) -> ok;
result_code_success(_) -> invalid_result_code.

% TODO Sync failure

-define (MAA_Errors(), #{
    invalid_result_code => #{error => "Unknown result code"},
    invalid_exp_result => #{error => "Unknown experimental result code"},
    unknown_user => #{error => "User is not known by HSS"}
}).

-spec parse_maa(#'MAA'{}) -> map().
parse_maa(#'MAA'{'Result-Code' = [ResultCode]} = Maa) ->
    Success = result_code_success(ResultCode),
    {Success, ResultCode};
parse_maa(#'MAA'{'Experimental-Result' = [#{'Vendor-Code' := ?VENDOR_ID_3GPP, 'ExpResultCode' := 5001}]} = Maa) ->
    {unknown_user, 5001};
parse_maa(#'MAA'{'Experimental-Result' = [#{'Vendor-Code' := ?VENDOR_ID_3GPP, 'ExpResultCode' := ResultCode}]} = Maa) ->
    {invalid_exp_result, ResultCode};
parse_maa(Maa) ->
    {unknown_err, []}.
% parse_maa(#'MAA'{'Experimental-Result-Code' = [ResultCode] = MAA) ->

-spec parse_saa(#'SAA'{}) -> map().
parse_saa(#'SAA'{'Result-Code' = [ResultCode]} = Saa) ->
    Success = result_code_success(ResultCode),
    {Success, ResultCode};
parse_saa(#'SAA'{'Experimental-Result' = [#{'Vendor-Code' := ?VENDOR_ID_3GPP, 'ExpResultCode' := 5001}]} = Saa) ->
    {unknown_user, 5001};
parse_saa(#'SAA'{'Experimental-Result' = [#{'Vendor-Code' := ?VENDOR_ID_3GPP, 'ExpResultCode' := ResultCode}]} = Saa) ->
    {invalid_exp_result, ResultCode};
parse_saa(Saa) ->
    {unknown_err, []}.

handle_call({mar, {IMSI, RAT, NumAuthItems, AuthScheme, PdpTypeNr, AuthorizationOpt}}, {Pid, _Tag} = _From, State) ->
    SessionId = diameter:session_id(application:get_env(?ENV_APP_NAME, origin_host, ?ENV_DEFAULT_ORIG_HOST)),
    % RFC 4005 6.11.1 Framed-IP-Address AVP:
    % "0xFFFFFFFE indicates that the NAS should select an address for the user
    % (e.g., assigned from a pool of addresses kept by the NAS)."
    Ipv4Dyn = <<16#FFFFFFFE:32>>,
    % 3GPP TS 29.229 6.3.54, RFC4005 6.11.6 2.3, RFC3162 2.3 allow empty prefix.
    % Set only the Reserved=0 byte and Prefix-Length=0
    IPv6Dyn = <<16#00:8,16#00:8>>,
    case PdpTypeNr of
    ?GTP_PDP_ADDR_TYPE_NR_IPv4 ->
        IPv4Opt = Ipv4Dyn,
        IPv6Opt = [];
    ?GTP_PDP_ADDR_TYPE_NR_IPv6 ->
        IPv4Opt = [],
        IPv6Opt = IPv6Dyn;
    ?GTP_PDP_ADDR_TYPE_NR_IPv4v6 ->
        IPv4Opt = Ipv4Dyn,
        IPv6Opt = IPv6Dyn;
    _ ->
        IPv4Opt = [],
        IPv6Opt = []
    end,
    lager:debug("Swx MAR: IPv4Opt=~p IPv6Opt=~p~n", [IPv4Opt, IPv6Opt]),
    MAR = #'MAR'{'Vendor-Specific-Application-Id' = #'Vendor-Specific-Application-Id'{
                    'Vendor-Id'           = ?VENDOR_ID_3GPP,
                    'Auth-Application-Id' = [?DIAMETER_APP_ID_SWX]},
                 'Session-Id' = SessionId,
                 'User-Name' = IMSI,
                 'Auth-Session-State' = 1,
                 'SIP-Auth-Data-Item' = #'SIP-Auth-Data-Item'{
                    'SIP-Authentication-Scheme' = [AuthScheme],
                    'SIP-Authorization' = AuthorizationOpt,
                    'Framed-IP-Address' = IPv4Opt,
                    'Framed-IPv6-Prefix' = IPv6Opt
                 },
                 'SIP-Number-Auth-Items' = NumAuthItems,
                 'RAT-Type' = RAT
                },
    lager:debug("Swx Tx MAR: ~p~n", [MAR]),
    Ret = diameter_call(MAR, Pid, State),
    case Ret of
        ok ->
            {reply, ok, State};
        {error, Err} ->
            lager:error("Error: ~w~n", [Err]),
            {reply, {error, Err}, State}
    end;

handle_call({sar, {IMSI, Type, APN, AgentInfoOpt}}, {Pid, _Tag} = _From, State) ->
    lager:debug("SWx Tx SAR Imsi=~p Type=~p APN=~p AgentInfoOpt=~p ~n", [IMSI, Type, APN, AgentInfoOpt]),
    SessionId = diameter:session_id(application:get_env(?ENV_APP_NAME, origin_host, ?ENV_DEFAULT_ORIG_HOST)),
    SAR = #'SAR'{'Vendor-Specific-Application-Id' = #'Vendor-Specific-Application-Id'{
                    'Vendor-Id'           = ?VENDOR_ID_3GPP,
                    'Auth-Application-Id' = [?DIAMETER_APP_ID_SWX]},
                 'Session-Id' = SessionId,
                 'User-Name' = IMSI,
                 'Auth-Session-State' = 1,
                 'Server-Assignment-Type' = Type,
                 'Service-Selection' = [APN],
                 'MIP6-Agent-Info' = AgentInfoOpt
                },
    Ret = diameter_call(SAR, Pid, State),
    case Ret of
        ok ->
            {reply, ok, State};
        {error, Err} ->
            lager:error("Error: ~w~n", [Err]),
            {reply, {error, Err}, State}
    end.

%% @callback gen_server
handle_cast(stop, State) ->
    {stop, normal, State};
handle_cast(_Req, State) ->
    {noreply, State}.

%% @callback gen_server
handle_info(_Info, State) ->
    {noreply, State}.

%% @callback gen_server
code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% @callback gen_server
terminate(normal, _State) ->
    diameter:stop_service(?SVC_NAME),
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

%% connect/3
connect(Name, {address, Protocol, IPAddr, Port}, {timer, ConnectTimer, WatchdogTimer, WatchdogConfig}) ->
    lager:notice("~s connecting to IP ~s port ~p~n", [Name, IPAddr, Port]),
    {ok, IP} = inet_parse:address(IPAddr),
    TransportOpts =
        [{transport_module, tmod(Protocol)},
         {transport_config,
          [{reuseaddr, true},
           {raddr, IP},
           {rport, Port}]},
         {connect_timer, ConnectTimer},
         {watchdog_timer, WatchdogTimer},
         {watchdog_config, WatchdogConfig}],
    diameter:add_transport(Name, {connect, TransportOpts}).

connect(Address, Timers) ->
    connect(?SVC_NAME, Address, Timers).

%% Convert connection type
tmod(tcp) ->
    diameter_tcp;
tmod(sctp) ->
    diameter_sctp.

diameter_call(Msg, Pid, State) ->
    diameter:call(?SVC_NAME, ?APP_ALIAS, Msg, [{extra, [Pid]},
                                               {timeout, State#swx_state.tx_timeout},
                                                detach]).


