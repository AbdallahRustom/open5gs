% AAA Server implementation of SWm Diameter interface, TS 29.273 section 7
% This interface is so far implemented through internal erlang messages against
% the internal ePDG.
-module(aaa_diameter_swm).
-behaviour(gen_server).

-include_lib("diameter_3gpp_ts29_273_swx.hrl").

-record(swm_state, {
	table_id, % ets table id,
	ues = sets:new()
}).

-record(swm_session, {
	imsi       :: binary(),
	pid        :: pid()
	}).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).
-export([code_change/3, terminate/2]).
-export([get_ue_fsm_by_imsi/1]).

-export([auth_request/1, auth_compl_request/2, session_termination_request/1]).
-export([auth_response/2, auth_compl_response/2]).

-define(SERVER, ?MODULE).

start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
	TableId = ets:new(auth_req, [bag, named_table]),
	{ok, #swm_state{table_id = TableId}}.

get_ue_fsm_by_imsi(Imsi) ->
	_Result = gen_server:call(?SERVER, {get_ue_fsm_by_imsi, Imsi}).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Tx over emulated SWm wire:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
auth_response(Imsi, Result) ->
	_Result = gen_server:call(?SERVER, {epdg_auth_resp, Imsi, Result}).

auth_compl_response(Imsi, Result) ->
	_Result = gen_server:call(?SERVER, {epdg_auth_compl_resp, Imsi, Result}).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Rx from emulated SWm wire:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
auth_request(Imsi) ->
	gen_server:cast(?SERVER, {epdg_auth_req, Imsi}).

auth_compl_request(Imsi, Apn) ->
	gen_server:cast(?SERVER, {epdg_auth_compl_req, Imsi, Apn}).

session_termination_request(Imsi) ->
	gen_server:cast(?SERVER, {str, Imsi}).

handle_cast({epdg_auth_req, Imsi}, State0) ->
	{Sess, State1} = find_or_new_swm_session(Imsi, State0),
	aaa_ue_fsm:ev_swm_auth_req(Sess#swm_session.pid),
	{noreply, State1};

handle_cast({epdg_auth_compl_req, Imsi, Apn}, State) ->
	Sess = find_swm_session_by_imsi(Imsi, State),
	case Sess of
	#swm_session{imsi = Imsi} ->
		aaa_ue_fsm:ev_swm_auth_compl(Sess#swm_session.pid, Apn);
	undefined ->
		epdg_diameter_swm:auth_compl_response(Imsi, {error, imsi_unknown})
	end,
	{noreply, State};

handle_cast({str, Imsi}, State) ->
	ok = epdg_diameter_swm:session_termination_answer(Imsi, 2001),
	{noreply, State};

handle_cast(Info, S) ->
	error_logger:error_report(["unknown handle_cast", {module, ?MODULE}, {info, Info}, {state, S}]),
	{noreply, S}.

handle_info(Info, S) ->
	error_logger:error_report(["unknown handle_info", {module, ?MODULE}, {info, Info}, {state, S}]),
	{noreply, S}.

handle_call({get_ue_fsm_by_imsi, Imsi}, _From, State) ->
	Sess = find_swm_session_by_imsi(Imsi, State),
	lager:debug("find_swm_session_by_imsi(~p) returned ~p~n", [Imsi, Sess]),
	case Sess of
	#swm_session{} ->
		{reply, {ok ,Sess#swm_session.pid}, State};
	undefined ->
		{reply, {error, imsi_unknown}, State}
	end;

handle_call({epdg_auth_resp, Imsi, Result}, _From, State) ->
	epdg_diameter_swm:auth_response(Imsi, Result),
	{reply, ok, State};

handle_call({epdg_auth_compl_resp, Imsi, Result}, _From, State) ->
	epdg_diameter_swm:auth_compl_response(Imsi, Result),
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

new_swm_session(Imsi, State) ->
	{ok, Pid} = aaa_ue_fsm:start_link(Imsi),
	UE = #swm_session{imsi = Imsi, pid = Pid},
	NewSt = State#swm_state{ues = sets:add_element(UE, State#swm_state.ues)},
	{UE, NewSt}.

% returns swm_session if found, undefined if not
find_swm_session_by_imsi(Imsi, State) ->
	sets:fold(
	    fun(UEsIt = #swm_session{imsi = Imsi}, _AccIn) -> UEsIt;
	       (_, AccIn) -> AccIn
	    end,
	    undefined,
	    State#swm_state.ues).

find_or_new_swm_session(Imsi, State) ->
	UE = find_swm_session_by_imsi(Imsi, State),
	case UE of
	    #swm_session{imsi = Imsi} ->
		{UE, State};
	    undefined ->
		new_swm_session(Imsi, State)
	end.

delete_swm_session(Imsi, State) ->
	SetRemoved = sets:del_element(Imsi, State#swm_state.ues),
	State#swm_state{ues = SetRemoved}.