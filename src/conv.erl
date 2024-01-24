% Conversion tools
% (C) 2023 by sysmocom
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
% along with this program.  If not, see <http://www.gnu.org/licenses/>.
%
% Additional Permission under GNU AGPL version 3 section 7:
%
% If you modify this Program, or any covered work, by linking or
% combining it with runtime libraries of Erlang/OTP as released by
% Ericsson on http://www.erlang.org (or a modified version of these
% libraries), containing parts covered by the terms of the Erlang Public
% License (http://www.erlang.org/EPLICENSE), the licensors of this
% Program grant you additional permission to convey the resulting work
% without the need to license the runtime libraries of Erlang/OTP under
% the GNU Affero General Public License. Corresponding Source for a
% non-source form of such a combination shall include the source code
% for the parts of the runtime libraries of Erlang/OTP used as well as
% that of the covered work.
%
-module(conv).
-author('Pau Espin Pedrol <pespin@sysmocom.de>').

-include_lib("osmo_gsup/include/gsup_protocol.hrl").
-include_lib("gtp_utils.hrl").

-export([cause_gtp2gsup/1]).

-spec cause_gtp2gsup(integer()) -> integer().

cause_gtp2gsup(?GTP2_CAUSE_REQUEST_ACCEPTED) -> 0;
cause_gtp2gsup(?GTP2_CAUSE_IMSI_IMEI_NOT_KNOWN) -> ?GSUP_CAUSE_IMSI_UNKNOWN;
cause_gtp2gsup(?GTP2_CAUSE_INVALID_PEER) -> ?GSUP_CAUSE_ILLEGAL_MS;
cause_gtp2gsup(?GTP2_CAUSE_DENIED_IN_RAT) -> ?GSUP_CAUSE_GPRS_NOTALLOWED;
cause_gtp2gsup(?GTP2_CAUSE_NETWORK_FAILURE) -> ?GSUP_CAUSE_NET_FAIL;
cause_gtp2gsup(?GTP2_CAUSE_APN_CONGESTION) -> ?GSUP_CAUSE_CONGESTION;
cause_gtp2gsup(?GTP2_CAUSE_GTP_C_ENTITY_CONGESTION) -> ?GSUP_CAUSE_CONGESTION;
cause_gtp2gsup(?GTP2_CAUSE_USER_AUTHENTICATION_FAILED) -> ?GSUP_CAUSE_GSM_AUTH_UNACCEPT;
cause_gtp2gsup(?GTP2_CAUSE_MANDATORY_IE_INCORRECT) -> ?GSUP_CAUSE_INV_MAND_INFO;
cause_gtp2gsup(?GTP2_CAUSE_MANDATORY_IE_MISSING) -> ?GSUP_CAUSE_INV_MAND_INFO;
cause_gtp2gsup(_) -> ?GSUP_CAUSE_PROTO_ERR_UNSPEC.
