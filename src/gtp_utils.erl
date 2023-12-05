% GTP utilities
%
% (C) 2023 by sysmocom - s.f.m.c. GmbH <info@sysmocom.de>
% Author: Alexander Couzens <lynxis@fe80.eu>
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

-module(gtp_utils).
-author('Alexander Couzens <lynxis@fe80.eu>').

-export([ip_to_bin/1, plmn_to_bin/3]).

% ergw_aaa/src/ergw_aaa_3gpp_dict.erl
% under GPLv2+
ip_to_bin(IP) when is_binary(IP) ->
    IP;
ip_to_bin({A, B, C, D}) ->
    <<A, B, C, D>>;
ip_to_bin({A, B, C, D, E, F, G, H}) ->
    <<A:16, B:16, C:16, D:16, E:16, F:16, G:16, H:16>>.

% ergw/apps/ergw/test/*.erl
% under GPLv2+
plmn_to_bin(CC, NC, NCSize) ->
    MCC = iolist_to_binary(io_lib:format("~3..0b", [CC])),
    MNC = iolist_to_binary(io_lib:format("~*..0b", [NCSize, NC])),
    {MCC, MNC}.
