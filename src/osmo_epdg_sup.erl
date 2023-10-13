-module(osmo_epdg_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-define(SERVER, ?MODULE).
-define(ENV_APP_NAME, osmo_epdg).
-define(ENV_DEFAULT_GSUP_LOCAL_IP, "0.0.0.0").
-define(ENV_DEFAULT_GSUP_LOCAL_PORT, 4222).

start_link() ->
	supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
	GsupLocalIp = application:get_env(?ENV_APP_NAME, gsup_local_ip, ?ENV_DEFAULT_GSUP_LOCAL_IP),
	GsupLocalPort = application:get_env(?ENV_APP_NAME, gsup_local_port, ?ENV_DEFAULT_GSUP_LOCAL_PORT),
	DiaServer = {epdg_diameter_swx, {epdg_diameter_swx,start_link,[]},
		     permanent,
		     5000,
		     worker,
		     [epdg_diameter_swx_cb]},
	GsupServer = {gsup_server, {gsup_server, start_link, [GsupLocalIp, GsupLocalPort, []]},
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
