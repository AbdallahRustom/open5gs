% (C) 2023 by sysmocom - s.f.m.c. GmbH <info@sysmocom.de>
% Author: Pau Espin Pedrol <pespin@sysmocom.de>
%
% All Rights Reserved
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU Affero General Public License as
% published by the Free Software Foundation; either version 3 of the
% License, or (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU Affero General Public License
% along with this program.  If not, see <https://www.gnu.org/licenses/>.
%
% Additional Permission under GNU AGPL version 3 section 7:
%
% If you modify this Program, or any covered work, by linking or
% combining it with runtime libraries of Erlang/OTP as released by
% Ericsson on https://www.erlang.org (or a modified version of these
% libraries), containing parts covered by the terms of the Erlang Public
% License (https://www.erlang.org/EPLICENSE), the licensors of this
% Program grant you additional permission to convey the resulting work
% without the need to license the runtime libraries of Erlang/OTP under
% the GNU Affero General Public License. Corresponding Source for a
% non-source form of such a combination shall include the source code
% for the parts of the runtime libraries of Erlang/OTP used as well as
% that of the covered work.


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
	GtpuLocalIp = get_config_gtpu_local_ip_addr(),
	%% AAA Server processes:
	AAADiaSWxServer = {aaa_diameter_swx, {aaa_diameter_swx,start_link,[]},
			   permanent,
			   5000,
			   worker,
			   [aaa_diameter_swx_cb]},
	AAADiaS6bServer = {aaa_diameter_s6b, {aaa_diameter_s6b,start_link,[]},
			   permanent,
			   5000,
			   worker,
			   [aaa_diameter_s6b_cb]},
	AAADiaSWmServer = {aaa_diameter_swm, {aaa_diameter_swm, start_link, []},
			   permanent,
			   5000,
			   worker,
			   [aaa_diameter_swm]},
	%% ePDG processes:
	GtpcServer = {epdg_gtpc_s2b, {epdg_gtpc_s2b,start_link, [GtpcLocalIp, GtpcLocalPort, GtpcRemoteIp, GtpcRemotePort, GtpuLocalIp, []]},
		      permanent,
		      5000,
		      worker,
		      [epdg_gtpc_s2b]},
	GsupServer = {gsup_server, {gsup_server, start_link, [GsupLocalIp, GsupLocalPort, []]},
		      permanent,
		      5000,
		      worker,
		      [gsup_server]},
	DiaSWmServer = {epdg_diameter_swm, {epdg_diameter_swm, start_link, []},
		        permanent,
		        5000,
		        worker,
		        [epdg_diameter_swm]},
	{ok, { {one_for_all, 5, 10}, [AAADiaSWxServer, AAADiaS6bServer, AAADiaSWmServer, GtpcServer, GsupServer, DiaSWmServer]} }.

% Returns GTP-U local IP address to use, as a string.
get_config_gtpu_local_ip_addr() ->
	GtpuKmodSockets = application:get_env(gtp_u_kmod, sockets, []),
	[GtpuKmodSocket | _] = GtpuKmodSockets,
	{_GtpuKmodName, GtpuKmodSockOpts} = GtpuKmodSocket,
	case proplists:get_value(ip, GtpuKmodSockOpts, undefined) of
	undefined ->
		GtpcLocalIp = application:get_env(?ENV_APP_NAME, gtpc_local_ip, ?ENV_DEFAULT_GTPC_LOCAL_IP),
		lager:notice("Config for GTP-U Local IP Address not found, using GTP-C ~p as fallback~n", [GtpcLocalIp]),
		GtpcLocalIp;
	IP ->
		% GtpuLocalIp is in format {A,B,C,D}, convert it to string:
		GtpuLocalIp = inet:ntoa(IP),
		lager:info("Config for GTP-U Local IP Address: ~p~n", [GtpuLocalIp]),
		GtpuLocalIp
	end.
