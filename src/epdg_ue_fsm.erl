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

-module(epdg_ue_fsm).
-behaviour(gen_statem).
-define(NAME, epdg_ue_fsm).

-include_lib("osmo_gsup/include/gsup_protocol.hrl").
-include_lib("gtplib/include/gtp_packet.hrl").
-include_lib("gtp_utils.hrl").
-include("conv.hrl").

-export([start/1, stop/1]).
-export([init/1,callback_mode/0,terminate/3]).
-export([get_server_name_by_imsi/1, get_pid_by_imsi/1]).
-export([auth_request/2, lu_request/1, tunnel_request/2, purge_ms_request/1,
         cancel_location_result/1]).
-export([received_swm_reauth_request/1, received_swm_dea_auth_response/2,
         received_swm_dea_auth_compl_response/2, received_swm_auth_answer/2,
         received_swm_session_termination_answer/2, received_swm_abort_session_request/1]).
-export([received_gtpc_create_session_response/2, received_gtpc_delete_session_response/2, received_gtpc_delete_bearer_request/1]).
-export([state_new/3,
         state_wait_auth_resp/3,
         state_authenticating/3,
         state_authenticated/3,
         state_wait_create_session_resp/3,
         state_active/3,
         state_wait_swm_session_termination_answer/3,
         state_wait_delete_session_resp/3,
         state_dereg_pgw_initiated_wait_cancel_location_res/3,
         state_dereg_net_initiated_wait_cancel_location_res/3,
         state_dereg_net_initiated_wait_s2b_delete_session_resp/3]).

-define(TIMEOUT_VAL_WAIT_GTP_ANSWER, 10000).
-define(TIMEOUT_VAL_WAIT_GSUP_ANSWER, 10000).
-define(TIMEOUT_VAL_WAIT_SWm_ANSWER, 10000).

-record(ue_fsm_data, {
        imsi,
        apn                     = "internet"    :: string(),
        pgw_rem_addr_list       = []            :: list(),
        tun_pdp_ctx                             :: #epdg_tun_pdp_ctx{},
        tear_down_gsup_needed   = false         :: boolean(), %% need to send GSUP PurgeMSResp after STR+STA?
        tear_down_gsup_cause    = 0             :: integer(),
        tear_down_s2b_needed    = false         :: boolean(), %% need to send S2b DeleteSessionReq
        tear_down_tx_swm_asa_needed = false         :: boolean() %% need to send SWm ASA
        }).

get_server_name_by_imsi(Imsi) ->
        ServerName = lists:concat([?NAME, "_", binary_to_list(Imsi)]),
        list_to_atom(ServerName).

get_pid_by_imsi(Imsi) ->
        ServerName = get_server_name_by_imsi(Imsi),
        whereis(ServerName).

start(Imsi) ->
        ServerName = get_server_name_by_imsi(Imsi),
        lager:info("ue_fsm start(~p)~n", [ServerName]),
        gen_statem:start({local, ServerName}, ?MODULE, Imsi, [{debug, [trace]}]).

stop(SrvRef) ->
        try
                gen_statem:stop(SrvRef)
        catch
        exit:Err ->
                {error, Err}
        end.

auth_request(Pid, {PdpTypeNr, Apn, EAP}) ->
        lager:info("ue_fsm auth_request~n", []),
        try
                gen_statem:call(Pid, {auth_request, PdpTypeNr, Apn, EAP})
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

tunnel_request(Pid, PCO) ->
        lager:info("ue_fsm tunnel_request(~p)~n", [PCO]),
        try
        gen_statem:call(Pid, {tunnel_request, PCO})
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

cancel_location_result(Pid) ->
        lager:info("ue_fsm cancel_location_result~n", []),
        try
                gen_statem:call(Pid, cancel_location_result)
        catch
        exit:Err ->
                {error, Err}
        end.

received_swm_reauth_request(Pid) ->
        lager:info("ue_fsm received_swm_reauth_request~n", []),
        try
        gen_statem:call(Pid, received_swm_reauth_request)
        catch
        exit:Err ->
                {error, Err}
        end.

received_swm_auth_answer(Pid, Result) ->
lager:info("ue_fsm received_swm_auth_answer~n", []),
try
gen_statem:call(Pid, {received_swm_auth_answer, Result})
catch
exit:Err ->
        {error, Err}
end.

received_swm_dea_auth_response(Pid, Result) ->
        lager:info("ue_fsm received_swm_dea_auth_response ~p~n", [Result]),
        try
        gen_statem:call(Pid, {received_swm_dea_auth_response, Result})
        catch
        exit:Err ->
                {error, Err}
        end.

received_swm_dea_auth_compl_response(Pid, Result) ->
        lager:info("ue_fsm received_swm_dea_auth_compl_response ~p~n", [Result]),
        try
        gen_statem:call(Pid, {received_swm_dea_auth_compl_response, Result})
        catch
        exit:Err ->
                {error, Err}
        end.

received_swm_session_termination_answer(Pid, Result) ->
        lager:info("ue_fsm received_swm_session_termination_answer ~p~n", [Result]),
        try
        gen_statem:call(Pid, {received_swm_sta, Result})
        catch
        exit:Err ->
                {error, Err}
        end.

received_swm_abort_session_request(Pid) ->
        lager:info("ue_fsm received_swm_abort_session_request~n", []),
        try
        gen_statem:call(Pid, received_swm_asr)
        catch
        exit:Err ->
                {error, Err}
        end.

received_gtpc_create_session_response(Pid, Result) ->
        lager:info("ue_fsm received_gtpc_create_session_response ~p~n", [Result]),
        try
        gen_statem:call(Pid, {received_gtpc_create_session_response, Result})
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

received_gtpc_delete_bearer_request(Pid) ->
        lager:info("ue_fsm received_gtpc_delete_bearer_request~n", []),
        try
        gen_statem:call(Pid, received_gtpc_delete_bearer_request)
        catch
        exit:Err ->
                {error, Err}
        end.


%% ------------------------------------------------------------------
%% Internal helpers
%% ------------------------------------------------------------------

ev_handle({call, From}, {auth_request, PdpTypeNr, Apn, EAP}, Data) ->
        epdg_diameter_swm:tx_der_auth_request(Data#ue_fsm_data.imsi, PdpTypeNr, Apn, EAP),
        {next_state, state_wait_auth_resp, Data, [{reply,From,ok}]}.

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
        case Data#ue_fsm_data.tun_pdp_ctx of
        undefined -> ok;
        _ -> gtp_u_tun:delete_pdp_context(Data#ue_fsm_data.tun_pdp_ctx)
        end,
        ok.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% state_new:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

state_new(enter, _OldState, Data) ->
        {keep_state, Data};

state_new({call, _From} = EvType, {auth_request, PdpTypeNr, Apn, EAP} = EvContent, Data) ->
        lager:info("ue_fsm state_new event=auth_request {~p, ~p, ~p}, ~p~n", [PdpTypeNr, Apn, EAP, Data]),
        ev_handle(EvType, EvContent, Data);

state_new({call, From}, purge_ms_request, Data) ->
        lager:info("ue_fsm state_new event=purge_ms_request, ~p~n", [Data]),
        {stop_and_reply, purge_ms_request, [{reply,From,ok}], Data}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% state_wait_auth_resp:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

state_wait_auth_resp(enter, _OldState, Data) ->
        {keep_state, Data, {state_timeout,?TIMEOUT_VAL_WAIT_SWm_ANSWER,swm_der_timeout}};

state_wait_auth_resp({call, From}, {received_swm_dea_auth_response, Result}, Data) ->
        lager:info("ue_fsm state_wait_auth_resp event=received_swm_dea_auth_response Result=~p, ~p~n", [Result, Data]),
        case Result of
                {ok, _AuthTuples} ->
                        gsup_server:auth_response(Data#ue_fsm_data.imsi, Result),
                        {next_state, state_authenticating, Data, [{reply,From,ok}]};
                {error, DiaRC} ->
                        GsupCause = conv:dia_rc_to_gsup_cause(DiaRC),
                        gsup_server:auth_response(Data#ue_fsm_data.imsi, {error, GsupCause}),
                        {next_state, state_new, Data, [{reply,From,ok}]};
                _ ->
                        {next_state, state_new, Data, [{reply,From,{error,unknown}}]}
        end;

state_wait_auth_resp(state_timeout, swm_der_timeout, Data) ->
        lager:error("ue_fsm state_wait_auth_resp: Timeout ~p, ~p~n", [swm_der_timeout, Data]),
        GsupCause = ?GSUP_CAUSE_NET_FAIL,
        gsup_server:auth_response(Data#ue_fsm_data.imsi, {error, GsupCause}),
        {next_state, state_new, Data}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% state_authenticating:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

state_authenticating(enter, _OldState, Data) ->
        {keep_state, Data};

state_authenticating({call, _From} = EvType, {auth_request, PdpTypeNr, Apn, EAP} = EvContent, Data) ->
        lager:info("ue_fsm state_authenticating event=auth_request {~p, ~p, ~p}, ~p~n", [PdpTypeNr, Apn, EAP, Data]),
        ev_handle(EvType, EvContent, Data);

state_authenticating({call, From}, lu_request, Data) ->
        lager:info("ue_fsm state_authenticating event=lu_request, ~p~n", [Data]),
        % Rx "GSUP CEAI LU Req" is our way of saying Rx "Swm Diameter-EAP REQ (DER) with EAP AVP containing successuful auth":
        epdg_diameter_swm:tx_der_auth_compl_request(Data#ue_fsm_data.imsi, Data#ue_fsm_data.apn),
        {keep_state, Data, [{reply,From,ok}]};

% Rx Swm Diameter-EAP Answer (DEA) containing APN-Configuration, triggered by
% earlier Tx DER EAP AVP containing successuful auth", when we received GSUP LU Req:
state_authenticating({call, From}, {received_swm_dea_auth_compl_response, Result}, Data) ->
        lager:info("ue_fsm state_authenticating event=lu_request, ~p, ~p~n", [Result, Data]),
        % Rx "GSUP CEAI LU Req" is our way of saying Rx "Swm Diameter-EAP REQ (DER) with EAP AVP containing successuful auth":
        case Result of
        {ok, ResInfo} ->
                % Store PGW Remote address if AAA/HSS signalled them to us:
                case maps:find(pdp_info_list, ResInfo) of
                error ->
                        Data1 = Data;
                PGWAddrCandidateList ->
                        Data1 = Data#ue_fsm_data{pgw_rem_addr_list = PGWAddrCandidateList}
                end,
                gsup_server:lu_response(Data1#ue_fsm_data.imsi, ok),
                {next_state, state_authenticated, Data1, [{reply,From,ok}]};
        {error, DiaRC} ->
                GsupCause = conv:dia_rc_to_gsup_cause(DiaRC),
                gsup_server:lu_response(Data#ue_fsm_data.imsi, {error, GsupCause}),
                {next_state, state_new, Data, [{reply,From,ok}]}
        end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% state_authenticated:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

state_authenticated(enter, _OldState, Data) ->
        {keep_state, Data};

state_authenticated({call, _From}, {auth_request, PdpTypeNr, Apn, EAP}, Data) ->
        lager:info("ue_fsm state_authenticated event=auth_request {~p, ~p, ~p}, ~p~n", [PdpTypeNr, Apn, EAP, Data]),
        {next_state, state_new, Data, [postpone]};

state_authenticated({call, From}, {tunnel_request, PCO}, Data) ->
        lager:info("ue_fsm state_authenticated event=tunnel_request, ~p~n", [Data]),
        epdg_gtpc_s2b:create_session_req(Data#ue_fsm_data.imsi,
                                         Data#ue_fsm_data.apn,
                                         PCO,
                                         Data#ue_fsm_data.pgw_rem_addr_list),
        {next_state, state_wait_create_session_resp, Data, [{reply,From,ok}]};

state_authenticated({call, From}, received_swm_reauth_request, Data) ->
        lager:info("ue_fsm state_authenticated event=received_swm_reauth_request, ~p~n", [Data]),
        epdg_diameter_swm:tx_reauth_answer(Data#ue_fsm_data.imsi, #epdg_dia_rc{result_code = 2001}),
        % 3GPP TS 29.273 7.1.2.5.1:
        % Upon receiving the re-authorization request, the ePDG shall immediately invoke the authorization procedure
        % specified in 7.1.2.2 for the session indicated in the request. This procedure is based on the Diameter
        % commands AA-Request (AAR) and AA-Answer (AAA) specified in IETF RFC 4005 [4]. Information
        % element contents for these messages are shown in tables 7.1.2.2.1/1 and 7.1.2.2.1/2.
        epdg_diameter_swm:tx_auth_req(Data#ue_fsm_data.imsi),
        {keep_state, Data, [{reply,From,ok}]};


state_authenticated({call, From}, {received_swm_auth_answer, Result}, Data) ->
        lager:info("ue_fsm state_authenticated event=received_swm_auth_answer(~p), ~p~n", [Result, Data]),
        case Result of
        ok ->
                {keep_state, Data, [{reply,From,ok}]};
        _ ->
                Data1 = Data#ue_fsm_data{tear_down_gsup_needed = false,
                                         tear_down_s2b_needed = false},
                {next_state, state_dereg_net_initiated_wait_cancel_location_res, Data1, [{reply,From,ok}]}
        end;

state_authenticated({call, From}, purge_ms_request, Data) ->
        lager:info("ue_fsm state_authenticated event=purge_ms_request, ~p~n", [Data]),
        Data1 = Data#ue_fsm_data{tear_down_gsup_needed = true},
        {next_state, state_wait_swm_session_termination_answer, Data1, [{reply,From,ok}]};

state_authenticated({call, From}, received_gtpc_delete_bearer_request, Data) ->
        lager:info("ue_fsm state_authenticated event=received_gtpc_delete_bearer_request, ~p~n", [Data]),
        Data1 = Data#ue_fsm_data{tear_down_gsup_needed = false},
        {next_state, state_dereg_pgw_initiated_wait_cancel_location_res, Data1, [{reply,From,ok}]};

state_authenticated({call, From}, Event, Data) ->
        lager:error("ue_fsm state_authenticated: Unexpected call event ~p, ~p~n", [Event, Data]),
        {keep_state, Data, [{reply,From,ok}]};

state_authenticated(cast, Event, Data) ->
        lager:error("ue_fsm state_authenticated: Unexpected cast event ~p, ~p~n", [Event, Data]),
        {keep_state, Data}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% state_wait_create_session_resp:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

state_wait_create_session_resp(enter, _OldState, Data) ->
        {keep_state, Data, [{state_timeout,?TIMEOUT_VAL_WAIT_GTP_ANSWER,create_session_timeout}]};

state_wait_create_session_resp({call, From}, {received_gtpc_create_session_response, Result}, Data) ->
        lager:info("ue_fsm state_authenticated event=received_gtpc_create_session_response, ~p~n", [Data]),
        case Result of
        {ok, ResInfo} ->
                #{eua := EUA,
                  local_teid := LocalTEID,
                  remote_teid := RemoteTEID,
                  remote_ipv4 := RemoteIPv4 % TODO: remote_ipv6
                  } = ResInfo,
                TunPdpCtx = #epdg_tun_pdp_ctx{local_teid = LocalTEID, remote_teid = RemoteTEID,
                                              eua = EUA, peer_addr = RemoteIPv4},
                Ret = gtp_u_tun:create_pdp_context(TunPdpCtx),
                lager:debug("gtp_u_tun:create_pdp_context(~p) returned ~p~n", [ResInfo, Ret]),
                Data1 = Data#ue_fsm_data{tun_pdp_ctx = TunPdpCtx},
                gsup_server:tunnel_response(Data1#ue_fsm_data.imsi, Result),
                {next_state, state_active, Data1, [{reply,From,ok}]};
        {error, GtpCause} ->
                GsupCause = conv:cause_gtp2gsup(GtpCause),
                gsup_server:tunnel_response(Data#ue_fsm_data.imsi, {error, GsupCause}),
                {next_state, state_authenticated, Data, [{reply,From,ok}]}
        end;

state_wait_create_session_resp({call, From}, Event, Data) ->
        lager:error("ue_fsm state_wait_create_session_resp: Unexpected call event ~p, ~p~n", [Event, Data]),
        {keep_state, Data, [{reply,From,{error,unexpected_event}}]};

state_wait_create_session_resp(state_timeout, create_session_timeout, Data) ->
        lager:error("ue_fsm state_wait_create_session_resp: Timeout ~p, ~p~n", [create_session_timeout, Data]),
        gsup_server:tunnel_response(Data#ue_fsm_data.imsi, {error, ?GSUP_CAUSE_CONGESTION}),
        {next_state, state_authenticated, Data}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% state_active:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

state_active(enter, _OldState, Data) ->
        {keep_state, Data};

state_active({call, _From}, {auth_request, PdpTypeNr, Apn, EAP}, Data) ->
        lager:info("ue_fsm state_active event=auth_request {~p, ~p, ~p}, ~p~n", [PdpTypeNr, Apn, EAP, Data]),
        gtp_u_tun:delete_pdp_context(Data#ue_fsm_data.tun_pdp_ctx),
        Data1 = Data#ue_fsm_data{tun_pdp_ctx = undefined},
        {next_state, state_new, Data1, [postpone]};

state_active({call, From}, received_swm_reauth_request, Data) ->
        lager:info("ue_fsm state_active event=received_swm_reauth_request, ~p~n", [Data]),
        epdg_diameter_swm:tx_reauth_answer(Data#ue_fsm_data.imsi, #epdg_dia_rc{result_code = 2001}),
        % 3GPP TS 29.273 7.1.2.5.1:
        % Upon receiving the re-authorization request, the ePDG shall immediately invoke the authorization procedure
        % specified in 7.1.2.2 for the session indicated in the request. This procedure is based on the Diameter
        % commands AA-Request (AAR) and AA-Answer (AAA) specified in IETF RFC 4005 [4]. Information
        % element contents for these messages are shown in tables 7.1.2.2.1/1 and 7.1.2.2.1/2.
        epdg_diameter_swm:tx_auth_req(Data#ue_fsm_data.imsi),
        {keep_state, Data, [{reply,From,ok}]};

state_active({call, From}, {received_swm_auth_answer, Result}, Data) ->
        lager:info("ue_fsm state_active event=received_swm_auth_answer(~p), ~p~n", [Result, Data]),
        case Result of
        ok ->
                {keep_state, Data, [{reply,From,ok}]};
        _ ->
                gtp_u_tun:delete_pdp_context(Data#ue_fsm_data.tun_pdp_ctx),
                Data1 = Data#ue_fsm_data{tun_pdp_ctx = undefined,
                                         tear_down_gsup_needed = false,
                                         tear_down_s2b_needed = true,
                                         tear_down_tx_swm_asa_needed = false},
                {next_state, state_dereg_net_initiated_wait_cancel_location_res, Data1, [{reply,From,ok}]}
        end;

state_active({call, From}, purge_ms_request, Data) ->
        lager:info("ue_fsm state_active event=purge_ms_request, ~p~n", [Data]),
        gtp_u_tun:delete_pdp_context(Data#ue_fsm_data.tun_pdp_ctx),
        Data1 = Data#ue_fsm_data{tun_pdp_ctx = undefined},
        case epdg_gtpc_s2b:delete_session_req(Data1#ue_fsm_data.imsi) of
        ok -> {next_state, state_wait_delete_session_resp, Data1, [{reply,From,ok}]};
        {error, Err} -> {keep_state, Data1, [{reply,From,{error, Err}}]}
        end;

state_active({call, From}, received_gtpc_delete_bearer_request, Data) ->
        lager:info("ue_fsm state_active event=received_gtpc_delete_bearer_request, ~p~n", [Data]),
        gtp_u_tun:delete_pdp_context(Data#ue_fsm_data.tun_pdp_ctx),
        Data1 = Data#ue_fsm_data{tun_pdp_ctx = undefined,
                                 tear_down_gsup_needed = false,
                                 tear_down_s2b_needed = false,
                                 tear_down_tx_swm_asa_needed = false},
        {next_state, state_dereg_pgw_initiated_wait_cancel_location_res, Data1, [{reply,From,ok}]};

%%% network (HSS/AAA) initiated de-registation requested:
state_active({call, From}, received_swm_asr, Data) ->
        lager:info("ue_fsm state_active event=received_swm_asr, ~p~n", [Data]),
        gtp_u_tun:delete_pdp_context(Data#ue_fsm_data.tun_pdp_ctx),
        Data1 = Data#ue_fsm_data{tun_pdp_ctx = undefined,
                                 tear_down_gsup_needed = false,
                                 tear_down_s2b_needed = true,
                                 tear_down_tx_swm_asa_needed = true},
        {next_state, state_dereg_net_initiated_wait_cancel_location_res, Data1, [{reply,From,ok}]};

state_active({call, From}, Event, Data) ->
        lager:error("ue_fsm state_active: Unexpected call event ~p, ~p~n", [Event, Data]),
        {keep_state, Data, [{reply,From,ok}]};

state_active(cast, Event, Data) ->
        lager:error("ue_fsm state_active: Unexpected cast event ~p, ~p~n", [Event, Data]),
        {keep_state, Data}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% state_wait_delete_session_resp:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

state_wait_delete_session_resp(enter, _OldState, Data) ->
        {keep_state, Data};

state_wait_delete_session_resp({call, From}, {received_gtpc_delete_session_response, _Resp = #gtp{version = v2, type = delete_session_response, ie = IEs}}, Data) ->
        lager:info("ue_fsm state_wait_delete_session_resp event=received_gtpc_delete_session_response, ~p~n", [Data]),
        #{{v2_cause,0} := CauseIE} = IEs,
        GtpCause = gtp_utils:enum_v2_cause(CauseIE#v2_cause.v2_cause),
        GsupCause = conv:cause_gtp2gsup(GtpCause),
        lager:debug("Cause: GTP_atom=~p -> GTP_int=~p -> GSUP_int=~p~n", [CauseIE#v2_cause.v2_cause, GtpCause, GsupCause]),
        Data1 = Data#ue_fsm_data{tear_down_gsup_needed = true},
        case GsupCause of
        0 -> Data2 = Data1;
        _ -> Data2 = Data1#ue_fsm_data{tear_down_gsup_cause = GsupCause}
        end,
        {next_state, state_wait_swm_session_termination_answer, Data2, [{reply,From,ok}]};

state_wait_delete_session_resp({call, From}, Event, Data) ->
        lager:error("ue_fsm state_wait_delete_session_resp: Unexpected call event ~p, ~p~n", [Event, Data]),
        {keep_state, Data, [{reply,From,{error,unexpected_event}}]}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% state_dereg_pgw_initiated_wait_cancel_location_res:
%% Network (PGW) initiated de-registration: We trigger GSUP Cancel Location Req.
%% Wait for GSUP Cancel Location Result.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
state_dereg_pgw_initiated_wait_cancel_location_res(enter, _OldState, Data) ->
        case gsup_server:cancel_location_request(Data#ue_fsm_data.imsi) of
        ok ->
                {keep_state, Data, {state_timeout,?TIMEOUT_VAL_WAIT_GSUP_ANSWER,gsup_cancel_location_timeout}};
        {error, _Err} ->
                {next_state, state_wait_swm_session_termination_answer, Data}
        end;

state_dereg_pgw_initiated_wait_cancel_location_res({call, From}, cancel_location_result, Data) ->
        lager:info("ue_fsm state_dereg_pgw_initiated_wait_cancel_location_res event=cancel_location_result, ~p~n", [Data]),
        {next_state, state_wait_swm_session_termination_answer, Data, [{reply,From,ok}]};

state_dereg_pgw_initiated_wait_cancel_location_res({call, From}, Event, Data) ->
        lager:error("ue_fsm state_dereg_pgw_initiated_wait_cancel_location_res: Unexpected call event ~p, ~p~n", [Event, Data]),
        {keep_state, Data, [{reply,From,ok}]};


state_dereg_pgw_initiated_wait_cancel_location_res(state_timeout, gsup_cancel_location_timeout, Data) ->
        lager:error("ue_fsm state_dereg_pgw_initiated_wait_cancel_location_res: Timeout ~p, ~p~n", [s2b_delete_session_timeout, Data]),
        {next_state, state_wait_swm_session_termination_answer, Data}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% state_wait_swm_session_termination_answer:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

state_wait_swm_session_termination_answer(enter, _OldState, Data) ->
        % Send STR towards AAA-Server
        % % 3GPP TS 29.273 7.1.2.3
        lager:info("ue_fsm state_wait_swm_session_termination_answer event=enter, ~p~n", [Data]),
        epdg_diameter_swm:tx_session_termination_request(Data#ue_fsm_data.imsi),
        {keep_state, Data, {state_timeout,?TIMEOUT_VAL_WAIT_SWm_ANSWER,swm_str_timeout}};

state_wait_swm_session_termination_answer({call, From}, {received_swm_sta, DiaRC}, Data) ->
        lager:info("ue_fsm state_wait_swm_session_termination_answer event=received_swm_sta, ~p~n", [Data]),
        case Data#ue_fsm_data.tear_down_gsup_needed of
        true ->
                case {DiaRC#epdg_dia_rc.result_code, Data#ue_fsm_data.tear_down_gsup_cause} of
                {2001, 0} -> gsup_server:purge_ms_response(Data#ue_fsm_data.imsi, ok);
                {2001, _} -> gsup_server:purge_ms_response(Data#ue_fsm_data.imsi, {error, Data#ue_fsm_data.tear_down_gsup_cause});
                _ -> gsup_server:purge_ms_response(Data#ue_fsm_data.imsi, {error, ?GSUP_CAUSE_NET_FAIL})
                end;
        false -> ok
        end,
        {stop_and_reply, normal, [{reply,From,ok}], Data};

state_wait_swm_session_termination_answer({call, From}, Event, Data) ->
        lager:error("ue_fsm state_wait_swm_session_termination_answer: Unexpected call event ~p, ~p~n", [Event, Data]),
        {keep_state, Data, [{reply,From,{error,unexpected_event}}]};

state_wait_swm_session_termination_answer(state_timeout, swm_str_timeout, Data) ->
        case Data#ue_fsm_data.tear_down_gsup_needed of
        true -> gsup_server:purge_ms_response(Data#ue_fsm_data.imsi, {error, ?GSUP_CAUSE_NET_FAIL});
        false -> ok
        end,
        {stop, normal}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% state_dereg_net_initiated_wait_cancel_location_res:
%% Network (AAA/HSS) initiated de-registration: We trigger GSUP Cancel Location Req.
%% Wait for GSUP Cancel Location Result, then continue to tear down S2b session.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
state_dereg_net_initiated_wait_cancel_location_res(enter, _OldState, Data) ->
        case gsup_server:cancel_location_request(Data#ue_fsm_data.imsi, ?GSUP_CANCELLATION_TYPE_WITHDRAW) of
        ok ->
                {keep_state, Data, {state_timeout,?TIMEOUT_VAL_WAIT_GSUP_ANSWER,gsup_cancel_location_timeout}};
        {error, _Err} ->
                {next_state, state_dereg_net_initiated_wait_s2b_delete_session_resp, Data}
        end;

state_dereg_net_initiated_wait_cancel_location_res({call, From}, cancel_location_result, Data) ->
        lager:info("ue_fsm state_dereg_net_initiated_wait_cancel_location_res event=cancel_location_result, ~p~n", [Data]),
        {next_state, state_dereg_net_initiated_wait_s2b_delete_session_resp, Data, [{reply,From,ok}]};

state_dereg_net_initiated_wait_cancel_location_res({call, From}, Event, Data) ->
        lager:error("ue_fsm state_dereg_net_initiated_wait_cancel_location_res: Unexpected call event ~p, ~p~n", [Event, Data]),
        {keep_state, Data, [{reply,From,ok}]};


state_dereg_net_initiated_wait_cancel_location_res(state_timeout, gsup_cancel_location_timeout, Data) ->
        lager:error("ue_fsm state_dereg_net_initiated_wait_cancel_location_res: Timeout ~p, ~p~n", [s2b_delete_session_timeout, Data]),
        {next_state, state_dereg_net_initiated_wait_s2b_delete_session_resp, Data}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% state_dereg_net_initiated_wait_s2b_delete_session_resp:
%% Network (AAA/HSS) initiated de-registration: We have informed UE (GSUP), and
%% have triggered GTPCv1 Delete Session Req against PGW.
%% Wait for GTPCv1 Delete Session Response, ssend SWm ASA to AAAA and terminate FSM.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
tx_swm_asa_if_needed(Data) ->
        case Data#ue_fsm_data.tear_down_tx_swm_asa_needed of
        true ->
                epdg_diameter_swm:tx_abort_session_answer(Data#ue_fsm_data.imsi);
        false -> lager:debug("Skip sending SWm ASA", [])
        end.

state_dereg_net_initiated_wait_s2b_delete_session_resp(enter, _OldState, Data) ->
        case Data#ue_fsm_data.tear_down_s2b_needed of
        true ->
                case epdg_gtpc_s2b:delete_session_req(Data#ue_fsm_data.imsi) of
                ok ->
                        {keep_state, Data, {state_timeout,?TIMEOUT_VAL_WAIT_GTP_ANSWER,s2b_delete_session_timeout}};
                {error, Err} ->
                        tx_swm_asa_if_needed(Data),
                        {stop, {error,Err}}
                end;
        false ->
                tx_swm_asa_if_needed(Data),
                {stop, normal}
        end;

state_dereg_net_initiated_wait_s2b_delete_session_resp({call, From}, {received_gtpc_delete_session_response, _Resp = #gtp{version = v2, type = delete_session_response, ie = IEs}}, Data) ->
        lager:info("ue_fsm state_dereg_net_initiated_wait_s2b_delete_session_resp event=received_gtpc_delete_session_response, ~p~n", [Data]),
        #{{v2_cause,0} := CauseIE} = IEs,
        GtpCause = gtp_utils:enum_v2_cause(CauseIE#v2_cause.v2_cause),
        lager:debug("Cause: GTP_atom=~p -> GTP_int=~p~n", [CauseIE#v2_cause.v2_cause, GtpCause]),
        tx_swm_asa_if_needed(Data),
        {stop_and_reply, normal, [{reply,From,ok}], Data};

state_dereg_net_initiated_wait_s2b_delete_session_resp({call, From}, Event, Data) ->
        lager:error("ue_fsm state_dereg_net_initiated_wait_s2b_delete_session_resp: Unexpected call event ~p, ~p~n", [Event, Data]),
        {keep_state, Data, [{reply,From,ok}]};


state_dereg_net_initiated_wait_s2b_delete_session_resp(state_timeout, s2b_delete_session_timeout, Data) ->
        lager:error("ue_fsm state_dereg_net_initiated_wait_s2b_delete_session_resp: Timeout ~p, ~p~n", [s2b_delete_session_timeout, Data]),
        tx_swm_asa_if_needed(Data),
        {stop, normal}.
