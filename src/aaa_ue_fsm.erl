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

-module(aaa_ue_fsm).
-behaviour(gen_statem).
-define(NAME, aaa_ue_fsm).

-include_lib("diameter/include/diameter.hrl").
-include_lib("diameter_3gpp_ts29_229.hrl").
-include_lib("diameter_3gpp_ts29_273_s6b.hrl").

-export([start_link/1]).
-export([init/1,callback_mode/0,terminate/3]).
-export([ev_swm_auth_req/1, ev_swm_auth_compl/2, ev_rx_swm_str/1, ev_rx_swx_maa/2, ev_rx_swx_saa/2,
         ev_rx_s6b_aar/2, ev_rx_s6b_str/1]).
-export([state_new/3, state_wait_swx_maa/3, state_wait_swx_saa/3, state_authenticated/3, state_authenticated_wait_swx_saa/3]).

-record(ue_fsm_data, {
        imsi             = unknown :: binary(),
        apn                        :: string(),
        epdg_sess_active = false   :: boolean(),
        pgw_sess_active  = false   :: boolean(),
        s6b_resp_pid               :: pid()
        }).

start_link(Imsi) ->
        ServerName = lists:concat([?NAME, "_", binary_to_list(Imsi)]),
        lager:info("ue_fsm start_link(~p)~n", [ServerName]),
        gen_statem:start_link({local, list_to_atom(ServerName)}, ?MODULE, Imsi, [{debug, [trace]}]).

ev_swm_auth_req(Pid) ->
        lager:info("ue_fsm ev_swm_auth_req~n", []),
        try
                gen_statem:call(Pid, swm_auth_req)
        catch
        exit:Err ->
                {error, Err}
        end.

ev_swm_auth_compl(Pid, Apn) ->
        lager:info("ue_fsm ev_swm_auth_compl~n", []),
        try
                gen_statem:call(Pid, {swm_auth_compl, Apn})
        catch
        exit:Err ->
                {error, Err}
        end.

ev_rx_swm_str(Pid) ->
        lager:info("ue_fsm ev_rx_swm_str~n", []),
        try
                gen_statem:call(Pid, rx_swm_str)
        catch
        exit:Err ->
                {error, Err}
        end.

ev_rx_swx_maa(Pid, MAA) ->
        lager:info("ue_fsm ev_rx_swx_maa~n", []),
        try
                gen_statem:call(Pid, {rx_swx_maa, MAA})
        catch
        exit:Err ->
                {error, Err}
        end.

ev_rx_swx_saa(Pid, {SAType, ResultCode}) ->
        lager:info("ue_fsm ev_rx_swx_saa~n", []),
        try
                gen_statem:call(Pid, {rx_swx_saa, SAType, ResultCode})
        catch
        exit:Err ->
                {error, Err}
        end.

ev_rx_s6b_aar(Pid, Apn) ->
        lager:info("ue_fsm ev_rx_s6b_aar: ~p~n", [Apn]),
        try
                gen_statem:call(Pid, {rx_s6b_aar, Apn})
        catch
        exit:Err ->
                {error, Err}
        end.

ev_rx_s6b_str(Pid) ->
        lager:info("ue_fsm ev_rx_s6b_str: ~p~n", []),
        try
                gen_statem:call(Pid, rx_s6b_str)
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
        [state_functions, state_enter].

terminate(Reason, State, Data) ->
        lager:info("terminating ~p with reason ~p state=~p, ~p~n", [?MODULE, Reason, State, Data]),
        ok.

state_new(enter, _OldState, Data) ->
        {keep_state, Data};

state_new({call, From}, swm_auth_req, Data) ->
        lager:info("ue_fsm state_new event=swm_auth_req, ~p~n", [Data]),
	% request the diameter code for a tuple
	CKey = [],
	IntegrityKey = [],
	case aaa_diameter_swx:multimedia_auth_request(Data#ue_fsm_data.imsi, 1, "EAP-AKA", 1, CKey, IntegrityKey) of
	ok -> {next_state, state_wait_swx_maa, Data, [{reply,From,ok}]};
	{error, Err} -> {keep_state, Data, [{reply,From,{error, Err}}]}
	end;

state_new({call, From}, {swm_auth_compl, Apn}, Data) ->
        lager:info("ue_fsm state_new event=swm_auth_compl, ~p~n", [Data]),
        case aaa_diameter_swx:server_assignment_request(Data#ue_fsm_data.imsi, 1, Apn) of
        ok -> {next_state, state_wait_swx_saa, Data, [{reply,From,ok}]};
        {error, Err} -> {keep_state, Data, [{reply,From,{error, Err}}]}
        end.

state_wait_swx_maa(enter, _OldState, Data) ->
        {keep_state, Data};

state_wait_swx_maa({call, From}, {rx_swx_maa, MAA}, Data) ->
        lager:info("ue_fsm state_wait_swx_maa event=rx_swx_maa, ~p~n", [Data]),
        aaa_diameter_swm:auth_response(Data#ue_fsm_data.imsi, {ok, MAA}),
        % TODO: don't transit if SAS returned error code.
        {next_state, state_new, Data, [{reply,From,ok}]}.

state_wait_swx_saa(enter, _OldState, Data) ->
        {keep_state, Data};

state_wait_swx_saa({call, From}, {rx_swx_saa, _SAType, ResultCode}, Data) ->
        lager:info("ue_fsm state_wait_swx_saa event=rx_swx_saa, ~p~n", [Data]),
        aaa_diameter_swm:auth_compl_response(Data#ue_fsm_data.imsi, {ok, ResultCode}),
        % TODO: don't transit if SAS returned error code.
        {next_state, state_authenticated, Data, [{reply,From,ok}]}.

state_authenticated(enter, _OldState, Data) ->
        % Mark ePDG session as active:
        Data1 = Data#ue_fsm_data{epdg_sess_active = true},
        {keep_state, Data1};

state_authenticated({call, {Pid, _Tag} = From}, {rx_s6b_aar, Apn}, Data) ->
        lager:info("ue_fsm state_authenticated event=rx_s6b_aar Apn=~p, ~p~n", [Apn, Data]),
        case aaa_diameter_swx:server_assignment_request(Data#ue_fsm_data.imsi,
                                                        ?'DIAMETER_CX_SERVER-ASSIGNMENT-TYPE_PGW_UPDATE',
                                                        Apn) of
        ok ->   Data1 = Data#ue_fsm_data{s6b_resp_pid = Pid, apn = Apn},
                {next_state, state_authenticated_wait_swx_saa, Data1, [{reply,From,ok}]};
        {error, Err} -> {keep_state, Data, [{reply,From,{error, Err}}]}
        end;

state_authenticated({call, From}, rx_swm_str, Data) ->
        lager:info("ue_fsm state_authenticated event=rx_swm_str, ~p~n", [Data]),
        case {Data#ue_fsm_data.epdg_sess_active, Data#ue_fsm_data.pgw_sess_active} of
        {false, _} -> %% The SWm session is not active...
                DiaRC = 5002, %% UNKNOWN_SESSION_ID
                {keep_state, Data, [{reply,From,{error, DiaRC}}]};
        {true, true} -> %% The other session is still active, no need to send SAR Type=USER_DEREGISTRATION
                lager:info("ue_fsm state_authenticated event=rx_swn_str: PGW session still active, skip updating the HSS~n", []),
                Data1 = Data#ue_fsm_data{epdg_sess_active = false},
                {keep_state, Data1, [{reply,From,{ok, 2001}}]};
        {true, false} -> %% All sessions will now be gone, trigger SAR Type=USER_DEREGISTRATION
                case aaa_diameter_swx:server_assignment_request(Data#ue_fsm_data.imsi,
                                                                ?'DIAMETER_CX_SERVER-ASSIGNMENT-TYPE_USER_DEREGISTRATION',
                                                                Data#ue_fsm_data.apn) of
                ok ->   {next_state, state_authenticated_wait_swx_saa, Data, [{reply,From,ok}]};
                {error, _Err} ->
                        DiaRC = 5002, %% UNKNOWN_SESSION_ID
                        {keep_state, Data, [{reply,From,{error, DiaRC}}]}
                end
        end;

state_authenticated({call, {Pid, _Tag} = From}, rx_s6b_str, Data) ->
        lager:info("ue_fsm state_authenticated event=rx_s6b_str, ~p~n", [Data]),
        case {Data#ue_fsm_data.pgw_sess_active, Data#ue_fsm_data.epdg_sess_active} of
        {false, _} -> %% The S6b session is not active...
                DiaRC = 5002, %% UNKNOWN_SESSION_ID
                {keep_state, Data, [{reply,From,{error, DiaRC}}]};
        {true, true} -> %% The other session is still active, no need to send SAR Type=USER_DEREGISTRATION
                lager:info("ue_fsm state_authenticated event=rx_s6b_str: ePDG session still active, skip updating the HSS~n", []),
                Data1 = Data#ue_fsm_data{pgw_sess_active = false},
                {keep_state, Data1, [{reply,From,{ok, 2001}}]};
        {true, false} -> %% All sessions will now be gone, trigger SAR Type=USER_DEREGISTRATION
                case aaa_diameter_swx:server_assignment_request(Data#ue_fsm_data.imsi,
                                                                ?'DIAMETER_CX_SERVER-ASSIGNMENT-TYPE_USER_DEREGISTRATION',
                                                                Data#ue_fsm_data.apn) of
                ok ->   Data1 = Data#ue_fsm_data{s6b_resp_pid = Pid},
                        {next_state, state_authenticated_wait_swx_saa, Data1, [{reply,From,ok}]};
                {error, _Err} ->
                        DiaRC = 5002, %% UNKNOWN_SESSION_ID
                        {keep_state, Data, [{reply,From,{error, DiaRC}}]}
                end
        end;

state_authenticated({call, From}, _Whatever, Data) ->
        lager:info("ue_fsm state_authenticated event=purge_ms_request, ~p~n", [Data]),
        {keep_state, Data, [{reply,From,ok}]}.

state_authenticated_wait_swx_saa(enter, _OldState, Data) ->
        {keep_state, Data};

state_authenticated_wait_swx_saa({call, From}, {rx_swx_saa, SAType, ResultCode}, Data) ->
        lager:info("ue_fsm state_authenticated_wait_swx_saa event=rx_swx_saa SAType=~p ResulCode=~p, ~p~n", [SAType, ResultCode, Data]),
        case SAType of
        ?'DIAMETER_CX_SERVER-ASSIGNMENT-TYPE_PGW_UPDATE' ->
                aaa_diameter_s6b:tx_aa_answer(Data#ue_fsm_data.s6b_resp_pid, ResultCode),
                Data1 = Data#ue_fsm_data{pgw_sess_active = true, s6b_resp_pid = undefined},
                {next_state, state_authenticated, Data1, [{reply,From,ok}]};
        ?'DIAMETER_CX_SERVER-ASSIGNMENT-TYPE_USER_DEREGISTRATION' ->
                case Data#ue_fsm_data.s6b_resp_pid of
                undefined -> %% SWm initiated
                        aaa_diameter_swm:session_termination_answer(Data#ue_fsm_data.imsi, ResultCode),
                        Data1 = Data#ue_fsm_data{epdg_sess_active = false},
                        {next_state, state_new, Data1, [{reply,From,ok}]};
                _ -> %% S6b initiated
                        aaa_diameter_s6b:tx_st_answer(Data#ue_fsm_data.s6b_resp_pid, ResultCode),
                        Data1 = Data#ue_fsm_data{pgw_sess_active = false, s6b_resp_pid = undefined},
                        {next_state, state_new, Data1, [{reply,From,ok}]}
                end
        end.