-module(epdg_sup).
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
        {ok, { {one_for_one, 5, 10}, [DiaServer]} }.
