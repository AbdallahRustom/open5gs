% AAA Server implementation of SWm Diameter interface, TS 29.273 section 7
% This interface is so far implemented through internal erlang messages against
% the internal ePDG.
-module(aaa_diameter_swm).
-behaviour(gen_server).

-include_lib("diameter_3gpp_ts29_273_swx.hrl").

-record(swm_state, {
	table_id % ets table id
}).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).
-export([code_change/3, terminate/2]).

-export[(auth_request/1)].

-define(SERVER, ?MODULE).

% The ets table contains only IMSIs

start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
	TableId = ets:new(auth_req, [bag, named_table]),
	{ok, #swm_state{table_id = TableId}}.


auth_request(Imsi) ->
	gen_server:cast(?SERVER, {epdg_auth_req, Imsi}).

handle_cast({epdg_auth_req, Imsi}, State) ->
	% request the diameter code for a tuple
	CKey = [],
	IntegrityKey = [],
	Result = aaa_diameter_swx:multimedia_auth_request(Imsi, 1, "EAP-AKA", 1, CKey, IntegrityKey),
	case Result of
		{ok, _MAA} -> epdg_diameter_swm:auth_response(Imsi, Result);
		{error, Err} -> epdg_diameter_swm:auth_response(Imsi, Result);
		_ -> epdg_diameter_swm:auth_response(Imsi, {error, unknown})
	end,
	{noreply, State};

handle_cast(Info, S) ->
	error_logger:error_report(["unknown handle_cast", {module, ?MODULE}, {info, Info}, {state, S}]),
	{noreply, S}.

handle_info(Info, S) ->
	error_logger:error_report(["unknown handle_info", {module, ?MODULE}, {info, Info}, {state, S}]),
	{noreply, S}.

handle_call(Request, From, S) ->
	error_logger:error_report(["unknown handle_call", {module, ?MODULE}, {request, Request}, {from, From}, {state, S}]),
	{noreply, S}.

stop() ->
	gen_server:call(?MODULE, stop).

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

terminate(Reason, _S) ->
	lager:info("terminating ~p with reason ~p~n", [?MODULE, Reason]).
