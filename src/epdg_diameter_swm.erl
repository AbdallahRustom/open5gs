% ePDG implementation of SWm Diameter interface, TS 29.273 section 7
% This interface is so far implemented through internal erlang messages against
% the internal AAA Server.
-module(epdg_diameter_swm).
-behaviour(gen_server).

-include_lib("diameter_3gpp_ts29_273_swx.hrl").

-record(swm_state, {
	sessions = sets:new()
}).

-record(swm_session, {
	imsi                   :: binary(),
	pid                    :: pid()
    }).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).
-export([code_change/3, terminate/2]).

-export([auth_request/1, auth_compl_request/2, session_termination_request/1]).
-export([auth_response/2, auth_compl_response/2, session_termination_answer/2]).

-define(SERVER, ?MODULE).

% The ets table contains only IMSIs

start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
	{ok, #swm_state{}}.


auth_request(Imsi) ->
	Result = gen_server:call(?SERVER, {epdg_auth_req, Imsi}),
	case Result of
		{ok, _Mar} ->
			epdg_ue_fsm:received_swm_auth_response(self(), Result),
			ok;
		_ -> Result
	end.

% Rx "GSUP CEAI LU Req" is our way of saying Rx "Swm Diameter-EAP REQ (DER) with EAP AVP containing successuful auth":
auth_compl_request(Imsi, Apn) ->
	Result = gen_server:call(?SERVER, {epdg_auth_compl_req, Imsi, Apn}),
	case Result of
		{ok, _Mar} ->
			epdg_ue_fsm:received_swm_auth_compl_response(self(), Result),
			ok;
		_ -> Result
	end.

% 3GPP TS 29.273 7.1.2.3
session_termination_request(Imsi) ->
	Result = gen_server:call(?SERVER, {str, Imsi}),
	case Result of
		{ok, _Mar} ->
			epdg_ue_fsm:received_swm_session_terminate_answer(self(), Result),
			ok;
		_ -> Result
	end.

handle_call({epdg_auth_req, Imsi}, {Pid, _Tag} = _From, State0) ->
	% we yet don't implement the Diameter SWm interface on the wire, we process the call internally:
	{_Sess, State1} = find_or_new_swm_session(Imsi, Pid, State0),
	ok = aaa_diameter_swm:auth_request(Imsi),
	{reply, ok, State1};

handle_call({epdg_auth_compl_req, Imsi, Apn}, _From, State) ->
	% we yet don't implement the Diameter SWm interface on the wire, we process the call internally:
	Sess = find_swm_session_by_imsi(Imsi, State),
	case Sess of
	#swm_session{imsi = Imsi} ->
		Reply = aaa_diameter_swm:auth_compl_request(Imsi, Apn);
	undefined ->
		Reply = {error,unknown_imsi}
	end,
	{reply, Reply, State};

handle_call({str, Imsi}, _From, State) ->
	% we yet don't implement the Diameter SWm interface on the wire, we process the call internally:
	Sess = find_swm_session_by_imsi(Imsi, State),
	case Sess of
	#swm_session{imsi = Imsi} ->
		Reply = aaa_diameter_swm:session_termination_request(Imsi);
	undefined ->
		Reply = {error,unknown_imsi}
	end,
	{reply, Reply, State}.

handle_cast({epdg_auth_resp, Imsi, Result}, State) ->
	Sess = find_swm_session_by_imsi(Imsi, State),
	case Sess of
	#swm_session{imsi = Imsi} ->
		epdg_ue_fsm:received_swm_auth_response(Sess#swm_session.pid, Result);
	undefined ->
		error_logger:error_report(["unknown swm_session", {module, ?MODULE}, {imsi, Imsi}, {state, State}])
	end,
	{noreply, State};

handle_cast({epdg_auth_compl_resp, Imsi, Result}, State) ->
	Sess = find_swm_session_by_imsi(Imsi, State),
	case Sess of
	#swm_session{imsi = Imsi} ->
		epdg_ue_fsm:received_swm_auth_compl_response(Sess#swm_session.pid, Result);
	undefined ->
		error_logger:error_report(["unknown swm_session", {module, ?MODULE}, {imsi, Imsi}, {state, State}])
	end,
	{noreply, State};

handle_cast({sta, Imsi, Result}, State) ->
	Sess = find_swm_session_by_imsi(Imsi, State),
	case Sess of
	#swm_session{imsi = Imsi} ->
		epdg_ue_fsm:received_swm_session_termination_answer(Sess#swm_session.pid, Result);
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
auth_response(Imsi, Result) ->
	ok = gen_server:cast(?SERVER, {epdg_auth_resp, Imsi, Result}).

%Rx Swm Diameter-EAP Answer (DEA) containing APN-Configuration, triggered by
%earlier Tx DER EAP AVP containing successuful auth":
auth_compl_response(Imsi, Result) ->
	ok = gen_server:cast(?SERVER, {epdg_auth_compl_resp, Imsi, Result}).

% Rx SWm Diameter STA:
session_termination_answer(Imsi, Result) ->
	ok = gen_server:cast(?SERVER, {sta, Imsi, Result}).

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

new_swm_session(Imsi, Pid, State) ->
	Sess = #swm_session{imsi = Imsi,
	    pid = Pid
	},
	NewSt = State#swm_state{sessions = sets:add_element(Sess, State#swm_state.sessions)},
	{Sess, NewSt}.

% returns Sess if found, undefined it not
find_swm_session_by_imsi(Imsi, State) ->
	{Imsi, Res} = sets:fold(
		fun(SessIt = #swm_session{imsi = LookupImsi}, {LookupImsi, _AccIn}) -> {LookupImsi, SessIt};
		(_, AccIn) -> AccIn
		end,
		{Imsi, undefined},
		State#swm_state.sessions),
	Res.

find_or_new_swm_session(Imsi, Pid, State) ->
	Sess = find_swm_session_by_imsi(Imsi, State),
	case Sess of
		#swm_session{imsi = Imsi} ->
		{Sess, State};
		undefined ->
		new_swm_session(Imsi, Pid, State)
	end.