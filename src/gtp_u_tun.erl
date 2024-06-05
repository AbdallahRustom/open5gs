% GTP-U tun related functionalities
%
% (C) 2024 by sysmocom - s.f.m.c. GmbH <info@sysmocom.de>
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

-module(gtp_u_tun).
-author('Pau Espin Pedrol <pespin@sysmocom.de>').
-include("conv.hrl").

-export([create_pdp_context/1, delete_pdp_context/1]).

%%%%%%%%%%%%%%%%%%%%%%
%%% Internal API
%%%%%%%%%%%%%%%%%%%%%%

% Obtain ServerRef of the gtp_u_kmod_port process spawned during startup based on
% gtp_u_kmod config:
get_env_gtp_u_kmod_server_ref() ->
        GtpuKmodSockets = application:get_env(gtp_u_kmod, sockets, []),
        [GtpuKmodSocket | _] = GtpuKmodSockets,
        {GtpuKmodName, _GtpuKmodSockOpts} = GtpuKmodSocket,
        GtpuKmodServRef = gtp_u_kmod_port:port_reg_name(GtpuKmodName),
        GtpuKmodServRef.


%%%%%%%%%%%%%%%%%%%%%%
%%% Internal API
%%%%%%%%%%%%%%%%%%%%%%

% Create a PDP Context on the GTP tundev
create_pdp_context(#epdg_tun_pdp_ctx{local_teid = LocalTEID,
                                     remote_teid = RemoteTEID,
                                     eua = EUA,
                                     peer_addr = PeerAddr}) ->
        PeerIP = conv:bin_to_ip(PeerAddr), % TODO: IPv6
        UEIP = conv:bin_to_ip(EUA#epdg_eua.ipv4), % TODO: IPv6.
        ServRef = get_env_gtp_u_kmod_server_ref(),
        gen_server:call(ServRef, {create_pdp_context, PeerIP, LocalTEID, RemoteTEID, UEIP}).

delete_pdp_context(#epdg_tun_pdp_ctx{local_teid = LocalTEID,
                                     remote_teid = RemoteTEID,
                                     eua = EUA,
                                     peer_addr = PeerAddr}) ->
        PeerIP = conv:bin_to_ip(PeerAddr), % TODO: IPv6
        UEIP = conv:bin_to_ip(EUA#epdg_eua.ipv4), % TODO: IPv6.
        ServRef = get_env_gtp_u_kmod_server_ref(),
        gen_server:call(ServRef, {delete_pdp_context, PeerIP, LocalTEID, RemoteTEID, UEIP}).
