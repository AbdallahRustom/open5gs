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

-include_lib("osmo_gsup/include/gsup_protocol.hrl").
-include_lib("gtplib/include/gtp_packet.hrl").

-export([start_link/1]).
-export([init/1,callback_mode/0,terminate/3]).
-export([auth_request/1, lu_request/1, tunnel_request/1, purge_ms_request/1]).
-export([received_gtpc_create_session_response/2, received_gtpc_delete_session_response/2]).
-export([state_new/3,state_authenticated/3, state_wait_delete_session_resp/3]).

-record(ue_fsm_data, {
        imsi
        }).

start_link(Imsi) ->
        ServerName = lists:concat([?NAME, "_", binary_to_list(Imsi)]),
        lager:info("ue_fsm start_link(~p)~n", [ServerName]),
        gen_statem:start_link({local, list_to_atom(ServerName)}, ?MODULE, Imsi, [{debug, [trace]}]).

auth_request(Pid) ->
        lager:info("ue_fsm auth_request~n", []),
        try
                gen_statem:call(Pid, auth_request)
        catch
        exit:Err ->
                {error, Err}
        end.

lu_request(Pid) ->
        lager:info("ue_fsm lu_request~n", []),
        try
                gen_statem:call(Pid, lu_request)
        catch
        exit:Err ->
                {error, Err}
        end.

tunnel_request(Pid) ->
        lager:info("ue_fsm tunnel_request~n", []),
        try
        gen_statem:call(Pid, tunnel_request)
        catch
        exit:Err ->
                {error, Err}
        end.

purge_ms_request(Pid) ->
        lager:info("ue_fsm purge_ms_request~n", []),
        try
        gen_statem:call(Pid, purge_ms_request)
        catch
        exit:Err ->
                {error, Err}
        end.

received_gtpc_create_session_response(Pid, Msg) ->
        lager:info("ue_fsm received_gtpc_create_session_response ~p~n", [Msg]),
        try
        gen_statem:call(Pid, {received_gtpc_create_session_response, Msg})
        catch
        exit:Err ->
                {error, Err}
        end.

received_gtpc_delete_session_response(Pid, Msg) ->
        lager:info("ue_fsm received_gtpc_delete_session_response ~p~n", [Msg]),
        try
        gen_statem:call(Pid, {received_gtpc_delete_session_response, Msg})
        catch
        exit:Err ->
                {error, Err}
        end.

%% ------------------------------------------------------------------
%% Internal helpers
%% ------------------------------------------------------------------

%% ------------------------------------------------------------------
%% gen_statem Function Definitions
%% ------------------------------------------------------------------

init(Imsi) ->
        lager:info("ue_fsm init(~p)~n", [Imsi]),
        Data = #ue_fsm_data{imsi = Imsi},
        {ok, state_new, Data}.

callback_mode() ->
        state_functions.

terminate(Reason, State, Data) ->
        lager:info("terminating ~p with reason ~p state=~p, ~p~n", [?MODULE, Reason, State, Data]),
        ok.

state_new({call, From}, auth_request, Data) ->
        lager:info("ue_fsm state_new event=auth_request, ~p~n", [Data]),
        Auth = auth_handler:auth_request(Data#ue_fsm_data.imsi),
        gsup_server:auth_response(Data#ue_fsm_data.imsi, Auth),
        case Auth of
                {ok, _} ->
                        {next_state, state_authenticated, Data, [{reply,From,ok}]};
		{error, Err} ->
                        {stop_and_reply, Err, Data, [{reply,From,{error,Err}}]}
	end;

state_new({call, From}, purge_ms_request, Data) ->
        lager:info("ue_fsm state_new event=purge_ms_request, ~p~n", [Data]),
        {stop_and_reply, purge_ms_request, Data, [{reply,From,ok}]}.

state_authenticated({call, From}, lu_request, Data) ->
        lager:info("ue_fsm state_authenticated event=lu_request, ~p~n", [Data]),
        Result = epdg_diameter_swx:server_assignment_request(Data#ue_fsm_data.imsi, 1, "internet"),
        gsup_server:lu_response(Data#ue_fsm_data.imsi, Result),
        case Result of
                {ok, _} ->
                        {keep_state, Data, [{reply,From,ok}]};
                {error, Err} ->
                        {stop, Err, Data, [{reply,From,{error,Err}}]}
        end;

state_authenticated({call, From}, tunnel_request, Data) ->
        lager:info("ue_fsm state_authenticated event=tunnel_request, ~p~n", [Data]),
        epdg_gtpc_s2b:create_session_req(Data#ue_fsm_data.imsi),
        {keep_state, Data, [{reply,From,ok}]};

state_authenticated({call, From}, {received_gtpc_create_session_response, Result}, Data) ->
        lager:info("ue_fsm state_authenticated event=received_gtpc_create_session_response, ~p~n", [Data]),
        gsup_server:tunnel_response(Data#ue_fsm_data.imsi, Result),
        {keep_state, Data, [{reply,From,ok}]};

state_authenticated({call, From}, purge_ms_request, Data) ->
        lager:info("ue_fsm state_authenticated event=purge_ms_request, ~p~n", [Data]),
        case epdg_gtpc_s2b:delete_session_req(Data#ue_fsm_data.imsi) of
        ok -> {next_state, state_wait_delete_session_resp, Data, [{reply,From,ok}]};
        {error, Err} -> {keep_state, Data, [{reply,From,{error, Err}}]}
        end;

state_authenticated({call, From}, _Whatever, Data) ->
        lager:error("ue_fsm state_authenticated: Unexpected call event, ~p~n", [Data]),
        {keep_state, Data, [{reply,From,ok}]};

state_authenticated(cast, _Whatever, Data) ->
        lager:error("ue_fsm state_authenticated: Unexpected cast event, ~p~n", [Data]),
        {keep_state, Data}.

state_wait_delete_session_resp({call, From}, {received_gtpc_delete_session_response, _Resp = #gtp{version = v2, type = delete_session_response, ie = IEs}}, Data) ->
        lager:info("ue_fsm state_wait_delete_session_resp event=received_gtpc_delete_session_response, ~p~n", [Data]),
        #{{v2_cause,0} := CauseIE} = IEs,
        GtpCause = gtp_utils:enum_v2_cause(CauseIE#v2_cause.v2_cause),
        GsupCause = conv:cause_gtp2gsup(GtpCause),
        lager:debug("Cause: GTP_atom=~p -> GTP_int=~p -> GSUP_int=~p~n", [CauseIE#v2_cause.v2_cause, GtpCause, GsupCause]),
        case GsupCause of
        0 -> gsup_server:purge_ms_response(Data#ue_fsm_data.imsi, ok);
        _ -> gsup_server:purge_ms_response(Data#ue_fsm_data.imsi, {error, GsupCause})
        end,
        {keep_state, Data, [{reply,From,ok}]};

state_wait_delete_session_resp({call, From}, Event, Data) ->
        lager:error("ue_fsm state_wait_delete_session_resp: Unexpected call event ~p, ~p~n", [Event, Data]),
        {keep_state, Data, [{reply,From,{error,unexpected_event}}]}.
