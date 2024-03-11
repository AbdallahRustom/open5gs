% AAA Server implementation of SWm Diameter interface, TS 29.273 section 7
% This interface is so far implemented through internal erlang messages against
% the internal ePDG.
-module(aaa_diameter_swm).
-behaviour(gen_server).

-include_lib("diameter_3gpp_ts29_273.hrl").

-record(swm_state, {
	table_id % ets table id
}).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).
-export([code_change/3, terminate/2]).

-export([auth_request/4, auth_compl_request/2, session_termination_request/1]).
-export([auth_response/2, auth_compl_response/2, session_termination_answer/2]).

-define(SERVER, ?MODULE).

start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
	TableId = ets:new(auth_req, [bag, named_table]),
	{ok, #swm_state{table_id = TableId}}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Tx over emulated SWm wire:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
auth_response(Imsi, Result) ->
	_Result = gen_server:call(?SERVER, {epdg_auth_resp, Imsi, Result}).

auth_compl_response(Imsi, Result) ->
	_Result = gen_server:call(?SERVER, {epdg_auth_compl_resp, Imsi, Result}).

session_termination_answer(Imsi, Result) ->
	_Result = gen_server:call(?SERVER, {sta, Imsi, Result}).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Rx from emulated SWm wire:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
auth_request(Imsi, PdpTypeNr, Apn, EAP) ->
	gen_server:cast(?SERVER, {epdg_auth_req, Imsi, PdpTypeNr, Apn, EAP}).

auth_compl_request(Imsi, Apn) ->
	gen_server:cast(?SERVER, {epdg_auth_compl_req, Imsi, Apn}).

session_termination_request(Imsi) ->
	gen_server:cast(?SERVER, {str, Imsi}).

handle_cast({epdg_auth_req, Imsi, PdpTypeNr, Apn, EAP}, State) ->
	case aaa_ue_fsm:get_pid_by_imsi(Imsi) of
		undefined -> {ok, Pid} = aaa_ue_fsm:start(Imsi);
		Pid -> Pid
	end,
	aaa_ue_fsm:ev_swm_auth_req(Pid, {PdpTypeNr, Apn, EAP}),
	{noreply, State};

handle_cast({epdg_auth_compl_req, Imsi, Apn}, State) ->
	case aaa_ue_fsm:get_pid_by_imsi(Imsi) of
	Pid when is_pid(Pid) ->
		aaa_ue_fsm:ev_swm_auth_compl(Pid, Apn);
	undefined ->
		RC_USER_UNKNOWN=5030,
		epdg_diameter_swm:auth_compl_response(Imsi, {error, RC_USER_UNKNOWN})
	end,
	{noreply, State};

handle_cast({str, Imsi}, State) ->
	case aaa_ue_fsm:get_pid_by_imsi(Imsi) of
	Pid when is_pid(Pid) ->
		case aaa_ue_fsm:ev_rx_swm_str(Pid) of
		ok -> ok; % Answering delayed due to SAR+SAA towards HSS.
		{ok, DiaRC} when is_integer(DiaRC) ->
			ok = epdg_diameter_swm:session_termination_answer(Imsi, DiaRC);
		{error, Err} when is_integer(Err) ->
			ok = epdg_diameter_swm:session_termination_answer(Imsi, Err);
		{error, _} ->
			ok = epdg_diameter_swm:session_termination_answer(Imsi, ?'RULE-FAILURE-CODE_CM_AUTHORIZATION_REJECTED')
		end;
	undefined ->
		ok = epdg_diameter_swm:session_termination_answer(Imsi, ?'RULE-FAILURE-CODE_CM_AUTHORIZATION_REJECTED')
	end,
	{noreply, State};

handle_cast(Info, S) ->
	error_logger:error_report(["unknown handle_cast", {module, ?MODULE}, {info, Info}, {state, S}]),
	{noreply, S}.

handle_info(Info, S) ->
	error_logger:error_report(["unknown handle_info", {module, ?MODULE}, {info, Info}, {state, S}]),
	{noreply, S}.

handle_call({epdg_auth_resp, Imsi, Result}, _From, State) ->
	epdg_diameter_swm:auth_response(Imsi, Result),
	{reply, ok, State};

handle_call({epdg_auth_compl_resp, Imsi, Result}, _From, State) ->
	epdg_diameter_swm:auth_compl_response(Imsi, Result),
	{reply, ok, State};

handle_call({sta, Imsi, DiaRC}, _From, State) ->
	epdg_diameter_swm:session_termination_answer(Imsi, DiaRC),
	{reply, ok, State};

handle_call(Request, From, S) ->
	error_logger:error_report(["unknown handle_call", {module, ?MODULE}, {request, Request}, {from, From}, {state, S}]),
	{noreply, S}.

stop() ->
	gen_server:call(?MODULE, stop).

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

terminate(Reason, _S) ->
	lager:info("terminating ~p with reason ~p~n", [?MODULE, Reason]).

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------
