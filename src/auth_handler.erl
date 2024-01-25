-module(auth_handler).
-behaviour(gen_server).

-include_lib("osmo_gsup/include/gsup_protocol.hrl").
-include_lib("diameter_3gpp_ts29_273_swx.hrl").

-record(auth_state, {
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
	{ok, #auth_state{table_id = TableId}}.


auth_request(Imsi) ->
	gen_server:call(?SERVER, {epdg_auth_req, Imsi}).

handle_call({epdg_auth_req, Imsi}, From, State) ->
	% request the diameter code for a tuple
	CKey = [],
	IntegrityKey = [],
	Result = aaa_diameter_swx:multimedia_auth_request(Imsi, 1, "EAP-AKA", 1, CKey, IntegrityKey),
	case Result of
		{ok, Mar} -> {reply, {ok, Mar}, State};
		{error, Err} -> {reply, {error, Err}, State};
		{_, _} -> {reply, {error, unknown}, State}
	end.

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
