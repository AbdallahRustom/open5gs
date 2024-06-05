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
%
-hrl_name('conv.hrl').

-define(VENDOR_ID_3GPP, 10415).

%% Can Hold information about Result-Code or Experimental-Result:
-record(epdg_dia_rc, {
        vendor_id      :: non_neg_integer(), %% or undefined if Result-Code
        result_code    :: non_neg_integer()
}).

-record(epdg_eua, {
        type_nr :: non_neg_integer(),
        ipv4    :: binary(),
        ipv6    :: binary()
}).

-record(epdg_tun_pdp_ctx, {
        local_teid   :: non_neg_integer(),
        remote_teid  :: non_neg_integer(),
        eua          :: epdg_eua,
        peer_addr    :: binary()
}).

-record(epdg_auth_tuple, {
        rand :: binary(),
        autn :: binary(),
        res  :: binary(),
        ik   :: binary(),
        ck   :: binary()
}).