% S6b: AAA side
%
% 3GPP TS 29.273 section 9
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


-module(aaa_diameter_s6b).
-author('Pau Espin Pedrol <pespin@sysmocom.de>').

-behaviour(gen_server).

-include_lib("diameter/include/diameter_gen_base_rfc6733.hrl").
-include_lib("diameter_3gpp_ts29_273_s6b.hrl").

%% API Function Exports
-export([start_link/0]).
-export([start/0, stop/0, terminate/2]).
%% gen_server Function Exports
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, peer_down/3]).
-export([code_change/3]).
-export([tx_reauth_request/1, tx_as_request/1]).
-export([tx_aa_answer/2, tx_st_answer/2]).

%% Diameter Application Definitions
-define(SERVER, ?MODULE).
-define(SVC_NAME, ?MODULE).
-define(APP_ALIAS, ?MODULE).
-define(CALLBACK_MOD, aaa_diameter_s6b_cb).
-define(DIAMETER_DICT_S6b, diameter_3gpp_ts29_273_s6b).
-define(ENV_APP_NAME, osmo_epdg).
-define(ENV_DEFAULT_SESSION_ID, "aaa@localdomain").
-define(ENV_DEFAULT_ORIG_REALM, "localdomain").
-define(ENV_DEFAULT_ORIG_HOST, "aaa.localdomain").
-define(ENV_DEFAULT_VENDOR_ID, 0).
-define(ENV_DEFAULT_DIAMETER_PROTO, sctp).
-define(ENV_DEFAULT_DIAMETER_REMOTE_IP, "127.0.0.10").
-define(ENV_DEFAULT_DIAMETER_REMOTE_PORT, 3868).
-define(ENV_DEFAULT_DIAMETER_CONNECT_TIMER_MS, 30000).
-define(ENV_DEFAULT_DIAMETER_WATCHDOG_TIMER_MS, 30000).
-define(ENV_DEFAULT_DIAMETER_WATCHDOG_CFG, [{okay, 3}, {suspect, 1}]).
-define(ENV_DEFAULT_DIAMETER_TRANSMIT_TIMER_MS, 10000).

-define(VENDOR_ID_3GPP, 10415).
-define(VENDOR_ID_3GPP2, 5535).
-define(VENDOR_ID_ETSI, 13019).
-define(DIAMETER_APP_ID_S6b, ?DIAMETER_DICT_S6b:id()).
%% The service configuration. As in the server example, a client
%% supporting multiple Diameter applications may or may not want to
%% configure a common callback module on all applications.
-define(SERVICE,
        [{'Origin-Host', application:get_env(?ENV_APP_NAME, dia_s6b_origin_host, ?ENV_DEFAULT_ORIG_HOST)},
         {'Origin-Realm', application:get_env(?ENV_APP_NAME, dia_s6b_origin_realm, ?ENV_DEFAULT_ORIG_REALM)},
         {'Vendor-Id', application:get_env(?ENV_APP_NAME, dia_s6b_vendor_id, ?ENV_DEFAULT_VENDOR_ID)},
         {'Vendor-Specific-Application-Id',
                [#'diameter_base_Vendor-Specific-Application-Id'{
                 'Vendor-Id'           = ?VENDOR_ID_3GPP,
                 'Auth-Application-Id' = [?DIAMETER_APP_ID_S6b]}]},
         {'Product-Name', "osmo-epdg-AAA"},
         % TODO: check which we should annouce here as Supported-Vendor-Id
         {'Supported-Vendor-Id', [?VENDOR_ID_3GPP, ?VENDOR_ID_ETSI, ?VENDOR_ID_3GPP2]},
         { application,
          [{alias, ?APP_ALIAS},
           {dictionary, ?DIAMETER_DICT_S6b},
           {module, ?CALLBACK_MOD},
           {answer_errors, callback}]}]).

-record(s6b_state, {
    tx_timeout :: non_neg_integer()
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

peer_down(_API, SvcName, {_PeerRef, _} = Peer) ->
    gen_server:cast(?SERVER, {peer_down, SvcName, Peer}),
    ok.

init([]) ->
    Proto = application:get_env(?ENV_APP_NAME, dia_s6b_proto, ?ENV_DEFAULT_DIAMETER_PROTO),
    Ip = application:get_env(?ENV_APP_NAME, dia_s6b_local_ip, ?ENV_DEFAULT_DIAMETER_REMOTE_IP),
    Port = application:get_env(?ENV_APP_NAME, dia_s6b_local_port, ?ENV_DEFAULT_DIAMETER_REMOTE_PORT),
    ConnectTimer = application:get_env(?ENV_APP_NAME, dia_s6b_connect_timer, ?ENV_DEFAULT_DIAMETER_CONNECT_TIMER_MS),
    WatchdogTimer = application:get_env(?ENV_APP_NAME, dia_s6b_watchdog_timer, ?ENV_DEFAULT_DIAMETER_WATCHDOG_TIMER_MS),
    WatchdogConfig = application:get_env(?ENV_APP_NAME, diameter_watchdog_config, ?ENV_DEFAULT_DIAMETER_WATCHDOG_CFG),
    TxTimer = application:get_env(?ENV_APP_NAME, dia_s6b_transmit_timer, ?ENV_DEFAULT_DIAMETER_TRANSMIT_TIMER_MS),
    ok = diameter:start_service(?MODULE, ?SERVICE),
    % lager:info("DiaServices is ~p~n", [DiaServ]),
    {ok, _} = listen({address, Proto, Ip, Port}, {timer, ConnectTimer, WatchdogTimer, WatchdogConfig}),
    {ok, #s6b_state{tx_timeout = TxTimer}}.

tx_aa_answer(Pid, DiaRC) ->
    % handle_request(AAR) was spawned into its own process, and it's blocked waiting for AAA:
    Pid ! {aaa, DiaRC}.

tx_st_answer(Pid, DiaRC) ->
    % handle_request(STR) was spawned into its own process, and it's blocked waiting for STA:
    Pid ! {sta, DiaRC}.

tx_reauth_request(NAI) ->
    gen_server:call(?SERVER, {rar, NAI}).

tx_as_request(NAI) ->
    gen_server:call(?SERVER, {asr, NAI}).

handle_call({rar, NAI}, _From, State) ->
    lager:debug("S6b Tx RAR NAI=~p~n", [NAI]),
    SessionId = diameter:session_id(application:get_env(?ENV_APP_NAME, dia_s6b_origin_host, ?ENV_DEFAULT_ORIG_HOST)),
    RAR = #'RAR'{'Session-Id' = SessionId,
                 'Auth-Application-Id' = ?DIAMETER_APP_ID_S6b,
                 'Re-Auth-Request-Type' = ?'RE-AUTH-REQUEST-TYPE_AUTHORIZE_ONLY',
                 'User-Name' = [NAI]
                },
    lager:debug("S6b Tx RAR: ~p~n", [RAR]),
    Ret = diameter_call(RAR, State),
    case Ret of
        ok ->
            {reply, ok, State};
        {error, Err} ->
            lager:error("Error: ~w~n", [Err]),
            {reply, {error, Err}, State}
    end;

handle_call({asr, NAI}, _From, State) ->
    lager:debug("S6b Tx ASR NAI=~p~n", [NAI]),
    SessionId = diameter:session_id(application:get_env(?ENV_APP_NAME, dia_s6b_origin_host, ?ENV_DEFAULT_ORIG_HOST)),
    ASR = #'ASR'{'Session-Id' = SessionId,
                 'Auth-Application-Id' = ?DIAMETER_APP_ID_S6b,
                 'User-Name' = [NAI],
                 'Auth-Session-State' = [?'AUTH-SESSION-STATE_NO_STATE_MAINTAINED']
                },
    lager:debug("S6b Tx ASR: ~p~n", [ASR]),
    Ret = diameter_call(ASR, State),
    case Ret of
        ok ->
            {reply, ok, State};
        {error, Err} ->
            lager:error("Error: ~w~n", [Err]),
            {reply, {error, Err}, State}
    end;

handle_call(Info, _From, State) ->
    error_logger:error_report(["unknown handle_call", {module, ?MODULE}, {info, Info}, {state, State}]).

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

listen(Name, {address, Protocol, IPAddr, Port}, {timer, ConnectTimer, WatchdogTimer, WatchdogConfig}) ->
    lager:notice("~s Listening on IP ~s port ~p~n", [Name, IPAddr, Port]),
    {ok, IP} = inet_parse:address(IPAddr),
    TransportOpts =
        [{transport_module, tmod(Protocol)},
         {transport_config,
          [{reuseaddr, true},
           {ip, IP},
           {port, Port}
           %%{raddr, IP},
           %%{rport, Port}
          ]},
         {connect_timer, ConnectTimer},
         {watchdog_timer, WatchdogTimer},
         {watchdog_config, WatchdogConfig}],
    diameter:add_transport(Name, {listen, TransportOpts}).

listen(Address, Timers) ->
    listen(?SVC_NAME, Address, Timers).

%% Convert connection type
tmod(tcp) ->
    diameter_tcp;
tmod(sctp) ->
    diameter_sctp.

diameter_call(Msg, State) ->
    diameter:call(?SVC_NAME, ?APP_ALIAS, Msg, [{timeout, State#s6b_state.tx_timeout},
                                                detach]).

