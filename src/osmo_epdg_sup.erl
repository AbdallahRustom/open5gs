-module(osmo_epdg_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-define(SERVER, ?MODULE).
start_link() ->
	supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
	DiaServer = {epdg_diameter_swx, {epdg_diameter_swx,start_link,[]},
		     permanent,
		     5000,
		     worker,
		     [epdg_diameter_swx_cb]},
	GsupServer = {gsup_server, {gsup_server, start_link, ["0.0.0.0", 4222, []]},
		      permanent,
		      5000,
		      worker,
		      [gsup_server]},
	AuthHandler = {auth_handler, {auth_handler, start_link, []},
		       permanent,
		       5000,
		       worker,
		       [auth_handler]},
	{ok, { {one_for_all, 5, 10}, [DiaServer, GsupServer, AuthHandler]} }.
