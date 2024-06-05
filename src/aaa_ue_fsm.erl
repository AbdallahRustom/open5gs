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

-module(aaa_ue_fsm).
-behaviour(gen_statem).
-define(NAME, aaa_ue_fsm).

-include_lib("diameter/include/diameter.hrl").
-include_lib("diameter_3gpp_ts29_229.hrl").
-include_lib("diameter_3gpp_ts29_273_s6b.hrl").
-include("conv.hrl").

-export([start/1, stop/1]).
-export([init/1,callback_mode/0,terminate/3]).
-export([get_server_name_by_imsi/1, get_pid_by_imsi/1]).
-export([ev_rx_swm_der_auth_req/2, ev_rx_swm_der_auth_compl/2,
         ev_rx_swm_reauth_answer/2, ev_rx_swm_auth_request/1,
         ev_rx_swm_str/1, ev_rx_swm_asa/1,
         ev_rx_swx_maa/2, ev_rx_swx_saa/2, ev_rx_swx_ppr/2, ev_rx_swx_rtr/1,
         ev_rx_s6b_aar/2, ev_rx_s6b_str/1, ev_rx_s6b_raa/2, ev_rx_s6b_asa/2]).
-export([state_new/3,
         state_wait_swx_maa/3,
         state_wait_swx_saa/3,
         state_authenticated/3,
         state_authenticated_wait_swx_saa/3,
         state_dereg_net_initiated_wait_s6b_asa/3,
         state_dereg_net_initiated_wait_swm_asa/3]).

-define(TIMEOUT_VAL_WAIT_S6b_ANSWER, 10000).
-define(TIMEOUT_VAL_WAIT_SWm_ANSWER, 10000).

-record(ue_fsm_data, {
        imsi                       :: string(),
        nai                        :: string(),
        apn                        :: string(),
        epdg_sess_active = false   :: boolean(),
        pgw_sess_active  = false   :: boolean(),
        s6b_resp_pid               :: pid()
        }).

get_server_name_by_imsi(Imsi) ->
        ServerName = lists:concat([?NAME, "_", Imsi]),
        list_to_atom(ServerName).

get_pid_by_imsi(Imsi) ->
        ServerName = get_server_name_by_imsi(Imsi),
        whereis(ServerName).

start(Imsi) ->
        ServerName = get_server_name_by_imsi(Imsi),
        lager:info("ue_fsm start_link(~p)~n", [ServerName]),
        gen_statem:start({local, ServerName}, ?MODULE, Imsi, [{debug, [trace]}]).

stop(SrvRef) ->
        try
                gen_statem:stop(SrvRef)
        catch
        exit:Err ->
                {error, Err}
        end.

ev_rx_swm_der_auth_req(Pid, {PdpTypeNr, Apn, EAP}) ->
        lager:info("ue_fsm ev_rx_swm_der_auth_req~n", []),
        try
                gen_statem:call(Pid, {rx_swm_der_auth_req, PdpTypeNr, Apn, EAP})
        catch
        exit:Err ->
                {error, Err}
        end.
ev_rx_swm_reauth_answer(Pid, Result) ->
        lager:info("ue_fsm ev_rx_swm_reauth_answer~n", []),
        try
                gen_statem:call(Pid, {rx_swm_reauth_answer, Result})
        catch
        exit:Err ->
                {error, Err}
        end.

ev_rx_swm_auth_request(Pid) ->
        lager:info("ue_fsm ev_rx_swm_auth_request~n", []),
        try
                gen_statem:call(Pid, rx_swm_auth_request)
        catch
        exit:Err ->
                {error, Err}
        end.

ev_rx_swm_der_auth_compl(Pid, Apn) ->
        lager:info("ue_fsm ev_rx_swm_der_auth_compl~n", []),
        try
                gen_statem:call(Pid, {rx_swm_der_auth_compl, Apn})
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

ev_rx_swm_asa(Pid) ->
        lager:info("ue_fsm ev_rx_swm_asa~n", []),
        try
                gen_statem:call(Pid, rx_swm_asa)
        catch
        exit:Err ->
                {error, Err}
        end.

ev_rx_swx_maa(Pid, Result) ->
        lager:info("ue_fsm ev_rx_swx_maa~n", []),
        try
                gen_statem:call(Pid, {rx_swx_maa, Result})
        catch
        exit:Err ->
                {error, Err}
        end.

ev_rx_swx_saa(Pid, Result) ->
        lager:info("ue_fsm ev_rx_swx_saa~n", []),
        try
                gen_statem:call(Pid, {rx_swx_saa, Result})
        catch
        exit:Err ->
                {error, Err}
        end.

ev_rx_swx_ppr(Pid, PGWAddresses) ->
        lager:info("ue_fsm ev_rx_swx_ppr~n", []),
        try
                gen_statem:call(Pid, {rx_swx_ppr, PGWAddresses})
        catch
        exit:Err ->
                {error, Err}
        end.

ev_rx_swx_rtr(Pid) ->
        lager:info("ue_fsm ev_rx_swx_rtr~n", []),
        try
                gen_statem:call(Pid, rx_swx_rtr)
        catch
        exit:Err ->
                {error, Err}
        end.

ev_rx_s6b_aar(Pid, {NAI, Apn, AgentInfoOpt}) ->
        lager:info("ue_fsm ev_rx_s6b_aar: ~p ~p ~p~n", [NAI, Apn, AgentInfoOpt]),
        try
                gen_statem:call(Pid, {rx_s6b_aar, NAI, Apn, AgentInfoOpt})
        catch
        exit:Err ->
                {error, Err}
        end.

ev_rx_s6b_raa(Pid, Result) ->
        lager:info("ue_fsm ev_rx_s6b_raa: ~p~n", [Result]),
        try
                gen_statem:call(Pid, {rx_s6b_raa, Result})
        catch
        exit:Err ->
                {error, Err}
        end.

ev_rx_s6b_asa(Pid, Result) ->
        lager:info("ue_fsm ev_rx_s6b_asa: ~p~n", [Result]),
        try
                gen_statem:call(Pid, {rx_s6b_asa, Result})
        catch
        exit:Err ->
                {error, Err}
        end.

ev_rx_s6b_str(Pid) ->
        lager:info("ue_fsm ev_rx_s6b_str~n", []),
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% state_new:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

state_new(enter, _OldState, Data) ->
        {keep_state, Data};

state_new({call, From}, {rx_swm_der_auth_req, PdpTypeNr, Apn, EAP}, Data) ->
        lager:info("ue_fsm state_new event=rx_swm_der_auth_req {~p, ~p, ~p}, ~p~n", [PdpTypeNr, Apn, EAP, Data]),
        case maps:find(authorization, EAP) of
        {ok, Authorization} when is_binary(Authorization) -> Authorization;
        error -> Authorization = []
        end,
        case aaa_diameter_swx:multimedia_auth_request(Data#ue_fsm_data.imsi, 1, 1, "EAP-AKA", PdpTypeNr, Authorization) of
        ok -> {next_state, state_wait_swx_maa, Data, [{reply,From,ok}]};
        {error, Err} -> {keep_state, Data, [{reply,From,{error, Err}}]}
        end;

state_new({call, From}, {rx_swm_der_auth_compl, Apn}, Data) ->
        lager:info("ue_fsm state_new event=rx_swm_der_auth_compl, ~p~n", [Data]),
        case aaa_diameter_swx:server_assignment_request(Data#ue_fsm_data.imsi, 1, Apn, []) of
        ok -> {next_state, state_wait_swx_saa, Data, [{reply,From,ok}]};
        {error, Err} -> {keep_state, Data, [{reply,From,{error, Err}}]}
        end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% state_wait_swx_maa:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

state_wait_swx_maa(enter, _OldState, Data) ->
        {keep_state, Data};

state_wait_swx_maa({call, From}, {rx_swx_maa, Result}, Data) ->
        lager:info("ue_fsm state_wait_swx_maa event=rx_swx_maa, ~p~n", [Data]),
        aaa_diameter_swm:tx_dea_auth_response(Data#ue_fsm_data.imsi, Result),
        {next_state, state_new, Data, [{reply,From,ok}]}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% state_wait_swx_saa:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

state_wait_swx_saa(enter, _OldState, Data) ->
        {keep_state, Data};

state_wait_swx_saa({call, From}, {rx_swx_saa, Result}, Data) ->
        lager:info("ue_fsm state_wait_swx_saa event=rx_swx_saa ~p, ~p~n", [Result, Data]),
        case Result of
        {error, _SAType, DiaRC} ->
                aaa_diameter_swm:tx_dea_auth_compl_response(Data#ue_fsm_data.imsi, {error, DiaRC}),
                {next_state, state_new, Data, [{reply,From,ok}]};
        {ok, _SAType, ResInfo} ->
                aaa_diameter_swm:tx_dea_auth_compl_response(Data#ue_fsm_data.imsi, {ok, ResInfo}),
                {next_state, state_authenticated, Data, [{reply,From,ok}]}
        end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% state_authenticated:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

state_authenticated(enter, _OldState, Data) ->
        % Mark ePDG session as active:
        Data1 = Data#ue_fsm_data{epdg_sess_active = true},
        {keep_state, Data1};

state_authenticated({call, {Pid, _Tag} = From}, {rx_s6b_aar, NAI, Apn, AgentInfoOpt}, Data) ->
        lager:info("ue_fsm state_authenticated event=rx_s6b_aar NAI=~p Apn=~p AgentInfo=~p, ~p~n", [NAI, Apn, AgentInfoOpt, Data]),
        %% TODO: Actually here we'd need to send SAR based on whether
        %% PGW Address changed in AgentInfoOpt, which for sure didn't in
        %% current status of osmo-epdg...
        case Data#ue_fsm_data.pgw_sess_active of
        false ->
                case aaa_diameter_swx:server_assignment_request(Data#ue_fsm_data.imsi,
                                                                ?'DIAMETER_CX_SERVER-ASSIGNMENT-TYPE_PGW_UPDATE',
                                                                Apn, AgentInfoOpt) of
                ok ->   Data1 = Data#ue_fsm_data{s6b_resp_pid = Pid, nai = NAI, apn = Apn},
                        {next_state, state_authenticated_wait_swx_saa, Data1, [{reply,From,ok}]};
                {error, Err} -> {keep_state, Data, [{reply,From,{error, Err}}]}
                end;
        true ->
                aaa_diameter_s6b:tx_aa_answer(Pid, #epdg_dia_rc{result_code = 2001}),
                {keep_state, Data, [{reply,From,ok}]}
        end;


state_authenticated({call, From}, rx_swm_str, Data) ->
        lager:info("ue_fsm state_authenticated event=rx_swm_str, ~p~n", [Data]),
        case {Data#ue_fsm_data.epdg_sess_active, Data#ue_fsm_data.pgw_sess_active} of
        {false, _} -> %% The SWm session is not active...
                DiaRC = 5002, %% UNKNOWN_SESSION_ID
                {keep_state, Data, [{reply,From,{error, DiaRC}}]};
        {true, true} -> %% The other session is still active, no need to send SAR Type=USER_DEREGISTRATION
                lager:info("ue_fsm state_authenticated event=rx_swm_str: PGW session still active, skip updating the HSS~n", []),
                Data1 = Data#ue_fsm_data{epdg_sess_active = false},
                {keep_state, Data1, [{reply,From,{ok, 2001}}]};
        {true, false} -> %% All sessions will now be gone, trigger SAR Type=USER_DEREGISTRATION
                case aaa_diameter_swx:server_assignment_request(Data#ue_fsm_data.imsi,
                                                                ?'DIAMETER_CX_SERVER-ASSIGNMENT-TYPE_USER_DEREGISTRATION',
                                                                Data#ue_fsm_data.apn, []) of
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
                DiaRC = #epdg_dia_rc{result_code = 5002}, %% UNKNOWN_SESSION_ID
                {keep_state, Data, [{reply,From,{error, DiaRC}}]};
        {true, true} -> %% The other session is still active, no need to send SAR Type=USER_DEREGISTRATION
                lager:info("ue_fsm state_authenticated event=rx_s6b_str: ePDG session still active, skip updating the HSS~n", []),
                Data1 = Data#ue_fsm_data{pgw_sess_active = false},
                DiaRC = #epdg_dia_rc{result_code = 2001}, %% SUCCESS
                {keep_state, Data1, [{reply,From,{ok, DiaRC}}]};
        {true, false} -> %% All sessions will now be gone, trigger SAR Type=USER_DEREGISTRATION
                case aaa_diameter_swx:server_assignment_request(Data#ue_fsm_data.imsi,
                                                                ?'DIAMETER_CX_SERVER-ASSIGNMENT-TYPE_USER_DEREGISTRATION',
                                                                Data#ue_fsm_data.apn, []) of
                ok ->   Data1 = Data#ue_fsm_data{s6b_resp_pid = Pid},
                        {next_state, state_authenticated_wait_swx_saa, Data1, [{reply,From,ok}]};
                {error, _Err} ->
                        DiaRC = #epdg_dia_rc{result_code = 5002}, %% UNKNOWN_SESSION_ID
                        {keep_state, Data, [{reply,From,{error, DiaRC}}]}
                end
        end;

state_authenticated({call, _From}, {rx_swm_der_auth_req, PdpTypeNr, Apn, EAP}, Data) ->
        lager:info("ue_fsm state_authenticated event=rx_swm_der_auth_req {~p, ~p, ~p}, ~p~n", [PdpTypeNr, Apn, EAP, Data]),
        {next_state, state_new, Data, [postpone]};

state_authenticated({call, From}, {rx_swx_ppr, _PGWAddresses}, Data) ->
        %% 3GPP TS 29.273 8.1.2.3.3:
        %% After a successful user profile download, the 3GPP AAA Server shall
        %% initiate re-authentication procedure as described
        %% in clause 7.2.2.4
        aaa_diameter_swm:tx_reauth_request(Data#ue_fsm_data.imsi),
        aaa_diameter_s6b:tx_reauth_request(Data#ue_fsm_data.nai),
        %% Following a successful download of subscription and equipment trace data, the 3GPP AAA Server shall forward the
        %% trace data by initiating reauthorization towards all PDN GWs that have an active authorization session.
        {keep_state, Data, [{reply,From,ok}]};

state_authenticated({call, From}, {rx_swm_reauth_answer, Result}, Data) ->
        lager:info("ue_fsm state_authenticated event=rx_swm_reauth_answer ~p, ~p~n", [Result, Data]),
        %% SWx PPA was already answered immediately when PPR was received, nothing to do here.
        {keep_state, Data, [{reply,From,ok}]};

state_authenticated({call, From}, rx_swm_auth_request, Data) ->
        lager:info("ue_fsm state_authenticated event=rx_swm_auth_request, ~p~n", [Data]),
        %% answer is trnamsitted when returning ok:
        {keep_state, Data, [{reply,From,ok}]};

state_authenticated({call, From}, {rx_s6b_raa, Result}, Data) ->
        lager:info("ue_fsm state_authenticated event=rx_s6b_raa ~p, ~p~n", [Result, Data]),
        %% SWx PPA was already answered immediately when PPR was received, nothing to do here.
        {keep_state, Data, [{reply,From,ok}]};

state_authenticated({call, From}, rx_swx_rtr, Data) ->
        lager:info("ue_fsm state_authenticated event=rx_swx_rtr ~p~n", [Data]),
        case {Data#ue_fsm_data.pgw_sess_active, Data#ue_fsm_data.epdg_sess_active} of
        {true, _} -> {next_state, state_dereg_net_initiated_wait_s6b_asa, Data, [{reply,From,ok}]};
        {false, _} -> {next_state, state_dereg_net_initiated_wait_s6b_asa, Data, [{reply,From,ok}]} %% TODO: proper state for s6b
        end;

state_authenticated({call, From}, Ev, Data) ->
        lager:info("ue_fsm state_authenticated: Unexpected call event ~p, ~p~n", [Ev, Data]),
        {keep_state, Data, [{reply,From,ok}]}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% state_authenticated_wait_swx_saa:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

state_authenticated_wait_swx_saa(enter, _OldState, Data) ->
        {keep_state, Data};

state_authenticated_wait_swx_saa({call, From}, {rx_swx_saa, Result}, Data) ->
        case Result of
        {error, SAType, DiaRC} -> DiaRC;
        {ok, SAType, _ResInfo} -> DiaRC = #epdg_dia_rc{result_code = 2001}
        end,
        lager:info("ue_fsm state_authenticated_wait_swx_saa event=rx_swx_saa SAType=~p ResulCode=~p, ~p~n", [SAType, DiaRC, Data]),
        case SAType of
        ?'DIAMETER_CX_SERVER-ASSIGNMENT-TYPE_PGW_UPDATE' ->
                aaa_diameter_s6b:tx_aa_answer(Data#ue_fsm_data.s6b_resp_pid, DiaRC),
                Data1 = Data#ue_fsm_data{pgw_sess_active = true, s6b_resp_pid = undefined},
                {next_state, state_authenticated, Data1, [{reply,From,ok}]};
        ?'DIAMETER_CX_SERVER-ASSIGNMENT-TYPE_USER_DEREGISTRATION' ->
                case Data#ue_fsm_data.s6b_resp_pid of
                undefined -> %% SWm initiated
                        aaa_diameter_swm:tx_session_termination_answer(Data#ue_fsm_data.imsi, DiaRC),
                        Data1 = Data#ue_fsm_data{epdg_sess_active = false},
                        {next_state, state_new, Data1, [{reply,From,ok}]};
                _ -> %% S6b initiated
                        aaa_diameter_s6b:tx_st_answer(Data#ue_fsm_data.s6b_resp_pid, DiaRC),
                        Data1 = Data#ue_fsm_data{pgw_sess_active = false, s6b_resp_pid = undefined},
                        {next_state, state_new, Data1, [{reply,From,ok}]}
                end
        end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% state_dereg_net_initiated_wait_s6b_asa:
%% HSS asked us to do deregistration towards the user.
%% Transmit S6b ASR towards PGW and wait for ASA back.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

state_dereg_net_initiated_wait_s6b_asa(enter, _OldState, Data) ->
        aaa_diameter_s6b:tx_as_request(Data#ue_fsm_data.nai),
        {keep_state, Data, {state_timeout,?TIMEOUT_VAL_WAIT_S6b_ANSWER,s6b_asa_timeout}};

state_dereg_net_initiated_wait_s6b_asa({call, From}, {rx_s6b_asa, _Result}, Data) ->
        {next_state, state_dereg_net_initiated_wait_swm_asa, Data, [{reply,From,ok}]};

state_dereg_net_initiated_wait_s6b_asa({call, From}, Ev, Data) ->
        lager:notice("ue_fsm state_dereg_net_initiated_wait_s6b_asa: Unexpected call event ~p, ~p~n", [Ev, Data]),
        {keep_state, Data, [{reply,From,ok}]};

state_dereg_net_initiated_wait_s6b_asa(state_timeout, s6b_asa_timeout, Data) ->
        {next_state, state_dereg_net_initiated_wait_swm_asa, Data}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% state_dereg_net_initiated_wait_s6b_asa:
%% HSS asked us to do deregistration towards the user.
%% S6b (PGW) was already torn down. Now transmit SWm ASR towards ePDG and wait for ASA back.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

state_dereg_net_initiated_wait_swm_asa(enter, _OldState, Data) ->
        aaa_diameter_swm:tx_as_request(Data#ue_fsm_data.imsi),
        {keep_state, Data, {state_timeout,?TIMEOUT_VAL_WAIT_SWm_ANSWER,swm_asa_timeout}};

state_dereg_net_initiated_wait_swm_asa({call, From}, rx_swm_asa, Data) ->
        {stop_and_reply, normal, [{reply,From,ok}], Data};

state_dereg_net_initiated_wait_swm_asa({call, From}, Ev, Data) ->
        lager:notice("ue_fsm state_dereg_net_initiated_wait_swm_asa: Unexpected call event ~p, ~p~n", [Ev, Data]),
        {keep_state, Data, [{reply,From,ok}]};

state_dereg_net_initiated_wait_swm_asa(state_timeout, swm_asa_timeout, _Data) ->
        {stop, normal}.
