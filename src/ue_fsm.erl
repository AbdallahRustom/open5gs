% UE FSM
% (C) 2023 by sysmocom
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

-module(ue_fsm).
-behaviour(gen_statem).
-define(NAME, ue_fsm).

-export([start_link/1]).
-export([init/1,callback_mode/0,terminate/3]).
-export([auth_request/1, lu_request/1, tunnel_request/1]).
-export([state_new/3,state_authenticated/3]).

-record(ue_fsm_data, {
        imsi
        }).

start_link(Imsi) ->
        ServerName = lists:concat([?NAME, "_", binary_to_list(Imsi)]),
        lager:info("ue_fsm start_link(~p)~n", [ServerName]),
        gen_statem:start_link({local, list_to_atom(ServerName)}, ?MODULE, Imsi, [{debug, [trace]}]).

auth_request(Pid) ->
        lager:info("ue_fsm auth_request~n", []),
        gen_statem:cast(Pid, auth_request).

lu_request(Pid) ->
        lager:info("ue_fsm lu_request~n", []),
        gen_statem:cast(Pid, lu_request).

tunnel_request(Pid) ->
        lager:info("ue_fsm tunnel_request~n", []),
        gen_statem:cast(Pid, tunnel_request).

init(Imsi) ->
        lager:info("ue_fsm init(~p)~n", [Imsi]),
        Data = #ue_fsm_data{imsi = Imsi},
        {ok, state_new, Data}.

callback_mode() ->
        state_functions.

terminate(Reason, State, Data) ->
        lager:info("terminating ~p with reason ~p state=~p, ~p~n", [?MODULE, Reason, State, Data]),
        ok.

state_new(cast, auth_request, Data) ->
        lager:info("ue_fsm state_new event=auth_request, ~p~n", [Data]),
        Auth = auth_handler:auth_request(Data#ue_fsm_data.imsi),
        gsup_server:auth_response(Data#ue_fsm_data.imsi, Auth),
        case Auth of
                {ok, _} ->
                        {next_state, state_authenticated, Data};
		{error, Err} ->
                        {stop, Err, Data}
	end.

state_authenticated(cast, lu_request, Data) ->
        lager:info("ue_fsm state_authenticated event=lu_request, ~p~n", [Data]),
        Result = epdg_diameter_swx:server_assignment_request(Data#ue_fsm_data.imsi, 1, "internet"),
        gsup_server:lu_response(Data#ue_fsm_data.imsi, Result),
        case Result of
                {ok, _} ->
                        {keep_state, Data};
                {error, Err} ->
                        {stop, Err, Data}
        end;

state_authenticated(cast, tunnel_request, Data) ->
        lager:info("ue_fsm state_authenticated event=tunnel_request, ~p~n", [Data]),
        Result = epdg_gtpc_s2b:create_session_req(Data#ue_fsm_data.imsi),
        gsup_server:tunnel_response(Data#ue_fsm_data.imsi, Result),
        case Result of
                {ok, _} ->
                        {keep_state, Data};
                {error, Err} ->
                        {stop, Err, Data}
        end;

state_authenticated(cast, _Whatever, Data) ->
        lager:info("ue_fsm state_authenticated event=auth_request, ~p~n", [Data]),
        {keep_state, Data}.