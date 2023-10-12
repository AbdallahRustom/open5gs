
-module(osmo_epdg_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
	lager:notice("osmo-epdg app started~n"),
	osmo_epdg_sup:start_link().

stop(_State) ->
	ok.
