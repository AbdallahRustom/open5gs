% ePDG implementation of SWm Diameter interface, TS 29.273 section 7
% This interface is so far implemented through internal erlang messages against
% the internal AAA Server.
-module(epdg_diameter_swm).
-behaviour(gen_server).

-include_lib("diameter_3gpp_ts29_273_swx.hrl").
-include("conv.hrl").

-record(swm_state, {
}).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).
-export([code_change/3, terminate/2]).

-export([tx_der_auth_request/4,
	 tx_reauth_answer/2,
	 tx_der_auth_compl_request/2,
	 tx_session_termination_request/1,
	 tx_abort_session_answer/1]).
-export([rx_dea_auth_response/2,
	 rx_dea_auth_compl_response/2,
	 rx_reauth_request/1,
	 rx_session_termination_answer/2,
	 rx_abort_session_request/1]).

-define(SERVER, ?MODULE).

% The ets table contains only IMSIs

start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
	{ok, #swm_state{}}.


%% Swm Diameter message Diameter-EAP-Request, 3GPP TS 29.273 Table 7.1.2.1.1
tx_der_auth_request(Imsi, PdpTypeNr, Apn, EAP) ->
	% In Diameter we use Imsi as strings, as done by diameter module.
	ImsiStr = binary_to_list(Imsi),
	% PdpTypeNr: SWm Diameter AVP "UE-Local-IP-Address"
	% Apn: SWm Diameter AVP "Service-Selection"
	% EAP: SWm Diameter AVP EAP-Payload
	Result = gen_server:call(?SERVER, {der_auth_req, ImsiStr, PdpTypeNr, Apn, EAP}),
	case Result of
		{ok, _AuthTuples} ->
			epdg_ue_fsm:received_swm_dea_auth_response(self(), Result),
			ok;
		_ -> Result
	end.

tx_reauth_answer(Imsi, DiaRC) ->
	% In Diameter we use Imsi as strings, as done by diameter module.
	ImsiStr = binary_to_list(Imsi),
	_Result = gen_server:call(?SERVER, {raa, ImsiStr, DiaRC}).

% Rx "GSUP CEAI LU Req" is our way of saying Rx "Swm Diameter-EAP REQ (DER) with EAP AVP containing successuful auth":
tx_der_auth_compl_request(Imsi, Apn) ->
	% In Diameter we use Imsi as strings, as done by diameter module.
	ImsiStr = binary_to_list(Imsi),
	Result = gen_server:call(?SERVER, {der_auth_compl_req, ImsiStr, Apn}),
	case Result of
		{ok, _Mar} ->
			epdg_ue_fsm:received_swm_dea_auth_compl_response(self(), Result),
			ok;
		_ -> Result
	end.

% 3GPP TS 29.273 7.1.2.3
tx_session_termination_request(Imsi) ->
	% In Diameter we use Imsi as strings, as done by diameter module.
	ImsiStr = binary_to_list(Imsi),
	Result = gen_server:call(?SERVER, {str, ImsiStr}),
	case Result of
		{ok, _Mar} ->
			epdg_ue_fsm:received_swm_session_terminate_answer(self(), Result),
			ok;
		_ -> Result
	end.

% 3GPP TS 29.273 7.1.2.4
tx_abort_session_answer(Imsi) ->
	% In Diameter we use Imsi as strings, as done by diameter module.
	ImsiStr = binary_to_list(Imsi),
	Result = gen_server:call(?SERVER, {asa, ImsiStr}),
	case Result of
		{ok, _Mar} ->
			ok;
		_ -> Result
	end.

handle_call({der_auth_req, Imsi, PdpTypeNr, Apn, EAP}, _From, State) ->
	% we yet don't implement the Diameter SWm interface on the wire, we process the call internally:
	ok = aaa_diameter_swm:rx_der_auth_request(Imsi, PdpTypeNr, Apn, EAP),
	{reply, ok, State};

handle_call({raa, Imsi, DiaRC}, _From, State) ->
	% we yet don't implement the Diameter SWm interface on the wire, we process the call internally:
	aaa_diameter_swm:rx_reauth_answer(Imsi, DiaRC#epdg_dia_rc.result_code),
	{reply, ok, State};

handle_call({der_auth_compl_req, Imsi, Apn}, _From, State) ->
	% we yet don't implement the Diameter SWm interface on the wire, we process the call internally:
	Reply = aaa_diameter_swm:rx_der_auth_compl_request(Imsi, Apn),
	{reply, Reply, State};

handle_call({str, Imsi}, _From, State) ->
	% we yet don't implement the Diameter SWm interface on the wire, we process the call internally:
	Reply = aaa_diameter_swm:rx_session_termination_request(Imsi),
	{reply, Reply, State};

handle_call({asa, Imsi}, _From, State) ->
	% we yet don't implement the Diameter SWm interface on the wire, we process the call internally:
	Reply = aaa_diameter_swm:rx_abort_session_answer(Imsi),
	{reply, Reply, State}.

handle_cast({dea_auth_resp, ImsiStr, Result}, State) ->
	Imsi = list_to_binary(ImsiStr),
	case epdg_ue_fsm:get_pid_by_imsi(Imsi) of
	Pid when is_pid(Pid) ->
		epdg_ue_fsm:received_swm_dea_auth_response(Pid, Result);
	undefined ->
		error_logger:error_report(["unknown swm_session", {module, ?MODULE}, {imsi, Imsi}, {state, State}])
	end,
	{noreply, State};

handle_cast({dea_auth_compl_resp, ImsiStr, Result}, State) ->
	Imsi = list_to_binary(ImsiStr),
	case epdg_ue_fsm:get_pid_by_imsi(Imsi) of
	Pid when is_pid(Pid) ->
		epdg_ue_fsm:received_swm_dea_auth_compl_response(Pid, Result);
	undefined ->
		error_logger:error_report(["unknown swm_session", {module, ?MODULE}, {imsi, Imsi}, {state, State}])
	end,
	{noreply, State};

handle_cast({rar, ImsiStr}, State) ->
	Imsi = list_to_binary(ImsiStr),
	case epdg_ue_fsm:get_pid_by_imsi(Imsi) of
	Pid when is_pid(Pid) ->
		case epdg_ue_fsm:received_swm_reauth_request(Pid) of
		ok ->
			DiaResultCode = 2001, %% SUCCESS
			aaa_diameter_swm:rx_reauth_answer(ImsiStr, DiaResultCode);
		_ ->
			DiaResultCode = 5012, %% UNABLE_TO_COMPLY
			aaa_diameter_swm:rx_reauth_answer(ImsiStr, DiaResultCode)
		end;
	undefined ->
		lager:notice("SWm Rx RAR: unknown swm-session ~p", [Imsi]),
		DiaResultCode = 5002, %% UNKNOWN_SESSION_ID
		aaa_diameter_swm:rx_reauth_answer(ImsiStr, DiaResultCode)
	end,
	{noreply, State};

handle_cast({sta, ImsiStr, Result}, State) ->
	Imsi = list_to_binary(ImsiStr),
	case epdg_ue_fsm:get_pid_by_imsi(Imsi) of
	Pid when is_pid(Pid) ->
		epdg_ue_fsm:received_swm_session_termination_answer(Pid, Result);
	undefined ->
		error_logger:error_report(["unknown swm_session", {module, ?MODULE}, {imsi, Imsi}, {state, State}])
	end,
	{noreply, State};

handle_cast({asr, ImsiStr}, State) ->
	Imsi = list_to_binary(ImsiStr),
	case epdg_ue_fsm:get_pid_by_imsi(Imsi) of
	Pid when is_pid(Pid) ->
		epdg_ue_fsm:received_swm_abort_session_request(Pid);
	undefined ->
		error_logger:error_report(["unknown swm_session", {module, ?MODULE}, {imsi, Imsi}, {state, State}])
	end,
	{noreply, State};

handle_cast(Info, S) ->
	error_logger:error_report(["unknown handle_cast", {module, ?MODULE}, {info, Info}, {state, S}]),
	{noreply, S}.
handle_info(Info, S) ->
	error_logger:error_report(["unknown handle_info", {module, ?MODULE}, {info, Info}, {state, S}]),
	{noreply, S}.


stop() ->
	gen_server:call(?MODULE, stop).

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

terminate(Reason, _S) ->
	lager:info("terminating ~p with reason ~p~n", [?MODULE, Reason]).

%% Emulation from the wire (DIAMETER SWm), called from internal AAA Server:
rx_reauth_request(Imsi) ->
	ok = gen_server:cast(?SERVER, {rar, Imsi}).

%% Emulation from the wire (DIAMETER SWm), called from internal AAA Server:
rx_dea_auth_response(Imsi, Result) ->
	ok = gen_server:cast(?SERVER, {dea_auth_resp, Imsi, Result}).

%Rx Swm Diameter-EAP Answer (DEA) containing APN-Configuration, triggered by
%earlier Tx DER EAP AVP containing successuful auth":
rx_dea_auth_compl_response(Imsi, Result) ->
	ok = gen_server:cast(?SERVER, {dea_auth_compl_resp, Imsi, Result}).

% Rx SWm Diameter STA:
rx_session_termination_answer(Imsi, Result) ->
	ok = gen_server:cast(?SERVER, {sta, Imsi, Result}).

% Rx SWm Diameter ASR:
rx_abort_session_request(Imsi) ->
	ok = gen_server:cast(?SERVER, {asr, Imsi}).

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------
