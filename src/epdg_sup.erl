-module(epdg_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-define(SERVER, ?MODULE).
start_link() ->
	supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
	% GSUP side
	%% HlrIp = application:get_env(osmo_dia2gsup, hlr_ip, "127.0.0.1"),
	%% HlrPort = application:get_env(osmo_dia2gsup, hlr_port, 4222),
	%% Args = [{local, gsup_client}, gsup_client, [HlrIp, HlrPort, []], [{debug, [trace]}]],
	%% GsupChild = {gsup_client, {gen_server, start_link, Args}, permanent, 2000, worker, [gsup_client]},
	% DIAMETER side
        DiaServer = {epdg_diameter_swx, {epdg_diameter_swx,start_link,[]},
                     permanent,
                     5000,
                     worker,
                     [swx_client_cb]},
%% DiaSuper = {diameter, {diameter,start_link,[]},
%%              permanent,
%%              5000,
%%              worker,
%%              []},
        {ok, { {one_for_one, 5, 10}, [DiaServer]} }.
