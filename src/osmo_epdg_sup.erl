-module(osmo_epdg_sup).
-behaviour(supervisor).

-export([start_link/0]).
-export([init/1]).

-define(SERVER, ?MODULE).
-define(ENV_APP_NAME, osmo_epdg).
-define(ENV_DEFAULT_GSUP_LOCAL_IP, "0.0.0.0").
-define(ENV_DEFAULT_GSUP_LOCAL_PORT, 4222).
-define(ENV_DEFAULT_GTPC_LOCAL_IP, "127.0.0.2").
-define(ENV_DEFAULT_GTPC_LOCAL_PORT, 2123).
-define(ENV_DEFAULT_GTPC_REMOTE_IP, "127.0.0.1").
-define(ENV_DEFAULT_GTPC_REMOTE_PORT, 2123).

start_link() ->
	supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
	GsupLocalIp = application:get_env(?ENV_APP_NAME, gsup_local_ip, ?ENV_DEFAULT_GSUP_LOCAL_IP),
	GsupLocalPort = application:get_env(?ENV_APP_NAME, gsup_local_port, ?ENV_DEFAULT_GSUP_LOCAL_PORT),
	GtpcLocalIp = application:get_env(?ENV_APP_NAME, gtpc_local_ip, ?ENV_DEFAULT_GTPC_LOCAL_IP),
	GtpcLocalPort = application:get_env(?ENV_APP_NAME, gtpc_local_port, ?ENV_DEFAULT_GTPC_LOCAL_PORT),
	GtpcRemoteIp = application:get_env(?ENV_APP_NAME, gtpc_remote_ip, ?ENV_DEFAULT_GTPC_REMOTE_IP),
	GtpcRemotePort = application:get_env(?ENV_APP_NAME, gtpc_remote_port, ?ENV_DEFAULT_GTPC_REMOTE_PORT),
	DiaServer = {epdg_diameter_swx, {epdg_diameter_swx,start_link,[]},
		     permanent,
		     5000,
		     worker,
		     [epdg_diameter_swx_cb]},
	DiaS6bServer = {aaa_diameter_s6b, {aaa_diameter_s6b,start_link,[]},
			permanent,
			5000,
			worker,
			[aaa_diameter_s6b_cb]},
	GtpcServer = {epdg_gtpc_s2b, {epdg_gtpc_s2b,start_link, [GtpcLocalIp, GtpcLocalPort, GtpcRemoteIp, GtpcRemotePort, []]},
		      permanent,
		      5000,
		      worker,
		      [epdg_gtpc_s2b]},
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
	{ok, { {one_for_all, 5, 10}, [DiaServer, DiaS6bServer, GtpcServer, GsupServer, AuthHandler]} }.
