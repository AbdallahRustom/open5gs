% SWx: AAA side
%
% TS 29.273
%
% (C) 2023 by sysmocom - s.m.f.c. GmbH <info@sysmocom.de>
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


-module(epdg_diameter_swx).
-author('Alexander Couzens <lynxis@fe80.eu>').

-behaviour(gen_server).

-include_lib("diameter_3gpp_ts29_273_swx.hrl").
-include_lib("diameter/include/diameter_gen_base_rfc6733.hrl").

%% API Function Exports
-export([start_link/0]).
-export([start/0, stop/0, terminate/2]).
%% gen_server Function Exports
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).
-export([code_change/3]).
-export([multimedia_auth_request/6]).
-export([server_assignment_request/3]).
-export([test/0, test/1]).

%% Diameter Application Definitions
-define(SERVER, ?MODULE).
-define(SVC_NAME, ?MODULE).
-define(APP_ALIAS, ?MODULE).
-define(CALLBACK_MOD, epdg_diameter_swx_cb).
-define(DIAMETER_DICT_SWX, diameter_3gpp_ts29_273_swx).

-define(VENDOR_ID_3GPP, 10415).
-define(VENDOR_ID_3GPP2, 5535).
-define(VENDOR_ID_ETSI, 13019).
-define(DIAMETER_APP_ID_SWX, ?DIAMETER_DICT_SWX:id()).
%% The service configuration. As in the server example, a client
%% supporting multiple Diameter applications may or may not want to
%% configure a common callback module on all applications.
-define(SERVICE,
                [{'Origin-Host', application:get_env(?SERVER, origin_host, "aaa.example.org")},
                 {'Origin-Realm', application:get_env(?SERVER, origin_realm, "realm.example.org")},
                 {'Vendor-Id', application:get_env(?SERVER, vendor_id, 0)},
                 {'Vendor-Specific-Application-Id',
                        [#'diameter_base_Vendor-Specific-Application-Id'{
                         'Vendor-Id'           = ?VENDOR_ID_3GPP,
                         'Auth-Application-Id' = [?DIAMETER_APP_ID_SWX]}]},
                 {'Product-Name', "osmo-epdg"},
                 {'Supported-Vendor-Id', [?VENDOR_ID_3GPP, ?VENDOR_ID_ETSI, ?VENDOR_ID_3GPP2]},
                 { application,
                 [{alias, ?APP_ALIAS}, {dictionary, ?DIAMETER_DICT_SWX}, {module, ?CALLBACK_MOD}]}]).

-record(state, {
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
    (catch ets:delete(?MODULE, {API, PeerRef})),
    gen_server:cast(?SERVER, {peer_down, SvcName, Peer}),
    ok.

init(State) ->
    Proto = application:get_env(?SERVER, diameter_proto, sctp),
    Ip = application:get_env(?SERVER, diameter_server_ip, "192.168.56.132"),
    Port = application:get_env(?SERVER, diameter_port, 3868),
    ok = diameter:start_service(?MODULE, ?SERVICE),
    % lager:info("DiaServices is ~p~n", [DiaServ]),
    {ok, _} = connect({address, Proto, Ip, Port}),
    {ok, State}.

test() ->
    test("262421234567890").

test(IMSI) ->
    multimedia_auth_request(IMSI, 3, "EAP-AKA", 1, [], []).

multimedia_auth_request(IMSI, NumAuthItems, AuthScheme, RAT, CKey, IntegrityKey) ->
    gen_server:call(?SERVER,
                          {mar, {IMSI, NumAuthItems, AuthScheme, RAT, CKey, IntegrityKey}}).
% APN is optional and should be []
server_assignment_request(IMSI, Type, APN) ->
    gen_server:call(?SERVER,
                          {sar, {IMSI, Type, APN}}).

% TODO Sync failure
handle_call({mar, {IMSI, NumAuthItems, AuthScheme, RAT, CKey, IntegrityKey}}, _From, State) ->
    SessionId = diameter:session_id(application:get_env(?SERVER, origin_host, "aaa.example.org")),
    MAR = #'MAR'{'Vendor-Specific-Application-Id' = #'Vendor-Specific-Application-Id'{
                    'Vendor-Id'           = ?VENDOR_ID_3GPP,
                    'Auth-Application-Id' = [?DIAMETER_APP_ID_SWX]},
                 'Session-Id' = SessionId,
                 'User-Name' = IMSI,
                 'Auth-Session-State' = 1,
                 'SIP-Auth-Data-Item' = #'SIP-Auth-Data-Item'{
                    'SIP-Authentication-Scheme' = [AuthScheme],
                    'Confidentiality-Key' = CKey,
                    'Integrity-Key' = IntegrityKey},
                 'SIP-Number-Auth-Items' = NumAuthItems,
                 'RAT-Type' = RAT
                },
    Ret = diameter:call(?SVC_NAME, ?APP_ALIAS, MAR, []),
    case Ret of
        {ok, MAA} ->
            {reply, {ok, MAA}, State};
        {error, Err} ->
            lager:error("Error: ~w~n", [Err]),
            {reply, {error, Err}, State}
    end;
handle_call({sar, {IMSI, Type, APN}}, _From, State) ->
    SessionId = diameter:session_id(application:get_env(?SERVER, origin_host, "aaa.example.org")),
    SAR = #'SAR'{'Vendor-Specific-Application-Id' = #'Vendor-Specific-Application-Id'{
                    'Vendor-Id'           = ?VENDOR_ID_3GPP,
                    'Auth-Application-Id' = [?DIAMETER_APP_ID_SWX]},
                 'Session-Id' = SessionId,
                 'User-Name' = IMSI,
                 'Auth-Session-State' = 1,
                 'Server-Assignment-Type' = Type,
                 'Service-Selection' = APN
                },
    Ret = diameter:call(?SVC_NAME, ?APP_ALIAS, SAR, []),
    case Ret of
        {ok, SAA} ->
            {reply, {ok, SAA}, State};
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

%% connect/2
connect(Name, {address, Protocol, IPAddr, Port}) ->
    {ok, IP} = inet_parse:address(IPAddr),
    TransportOpts =
        [{transport_module, tmod(Protocol)},
         {transport_config,
          [{reuseaddr, true},
           {raddr, IP},
           {rport, Port}]}],
    diameter:add_transport(Name, {connect, [{reconnect_timer, 1000} | TransportOpts]}).

connect(Address) ->
    connect(?SVC_NAME, Address).

%% Convert connection type
tmod(tcp) ->
    diameter_tcp;
tmod(sctp) ->
    diameter_sctp.


