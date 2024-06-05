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
-module(conv).
-author('Pau Espin Pedrol <pespin@sysmocom.de>').

-include_lib("osmo_gsup/include/gsup_protocol.hrl").
-include_lib("gtplib/include/gtp_packet.hrl").
-include_lib("gtp_utils.hrl").
-include_lib("conv.hrl").

-export([ip_to_bin/1, bin_to_ip/1]).
-export([cause_gtp2gsup/1]).
-export([dia_rc_success/1, dia_rc_to_gsup_cause/1]).
-export([gtp2_paa_to_epdg_eua/1, epdg_eua_to_gsup_pdp_address/1]).
-export([nai_to_imsi/1]).

% ergw_aaa/src/ergw_aaa_3gpp_dict.erl
% under GPLv2+
ip_to_bin(IP) when is_binary(IP) ->
        IP;
    ip_to_bin({A, B, C, D}) ->
        <<A, B, C, D>>;
    ip_to_bin({A, B, C, D, E, F, G, H}) ->
        <<A:16, B:16, C:16, D:16, E:16, F:16, G:16, H:16>>.

    bin_to_ip(<<A:8, B:8, C:8, D:8>> = IP) when is_binary(IP) ->
        {A, B, C, D};
    bin_to_ip(<<A:16, B:16, C:16, D:16, E:16, F:16, G:16, H:16>> = IP) when is_binary(IP) ->
        {A, B, C, D, E, F, G, H};
    bin_to_ip({_, _, _, _} = IP) ->
        IP;
    bin_to_ip({_, _, _, _, _, _, _, _} = IP) ->
        IP.

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


-define(DIA_VENDOR_3GPP, 10415).
% transient (only in Experimental-Result-Code)
-define(DIAMETER_AUTHENTICATION_DATA_UNAVAILABLE,	4181).
-define(DIAMETER_ERROR_CAMEL_SUBSCRIPTION_PRESENT,	4182).
% permanent (only in Experimental-Result-Code)
-define(DIAMETER_ERROR_USER_UNKNOWN,			5001).
-define(DIAMETER_AUTHORIZATION_REJECTED,		5003).
-define(DIAMETER_ERROR_ROAMING_NOT_ALLOWED,		5004).
-define(DIAMETER_MISSING_AVP,				5005).
-define(DIAMETER_UNABLE_TO_COMPLY,			5012).
-define(DIAMETER_ERROR_UNKNOWN_EPS_SUBSCRIPTION,	5420).
-define(DIAMETER_ERROR_RAT_NOT_ALLOWED,			5421).
-define(DIAMETER_ERROR_EQUIPMENT_UNKNOWN,		5422).
-define(DIAMETER_ERROR_UNKOWN_SERVING_NODE,		5423).

dia_rc_success(#epdg_dia_rc{result_code = 2001}) -> ok;
dia_rc_success(#epdg_dia_rc{result_code = 2002}) -> ok;
dia_rc_success(_) -> invalid_result_code.

-spec dia_rc_to_gsup_cause(#epdg_dia_rc{}) -> non_neg_integer().
dia_rc_to_gsup_cause(#epdg_dia_rc{result_code = 2001}) -> 0;
dia_rc_to_gsup_cause(#epdg_dia_rc{result_code = 2002}) -> 0;
dia_rc_to_gsup_cause(#epdg_dia_rc{result_code = ?DIAMETER_ERROR_USER_UNKNOWN}) -> ?GSUP_CAUSE_IMSI_UNKNOWN;
dia_rc_to_gsup_cause(#epdg_dia_rc{result_code = ?DIAMETER_AUTHORIZATION_REJECTED}) -> ?GSUP_CAUSE_LA_NOTALLOWED;
dia_rc_to_gsup_cause(#epdg_dia_rc{result_code = ?DIAMETER_ERROR_ROAMING_NOT_ALLOWED}) -> ?GSUP_CAUSE_ROAMING_NOTALLOWED;
dia_rc_to_gsup_cause(#epdg_dia_rc{result_code = ?DIAMETER_ERROR_UNKNOWN_EPS_SUBSCRIPTION}) -> ?GSUP_CAUSE_NO_SUIT_CELL_IN_LA;
dia_rc_to_gsup_cause(#epdg_dia_rc{result_code = ?DIAMETER_UNABLE_TO_COMPLY}) -> ?GSUP_CAUSE_NET_FAIL;
dia_rc_to_gsup_cause(#epdg_dia_rc{result_code = ?DIAMETER_MISSING_AVP}) -> ?GSUP_CAUSE_PROTO_ERR_UNSPEC;
dia_rc_to_gsup_cause(_) -> ?GSUP_CAUSE_NET_FAIL.

gtp2_paa_to_epdg_eua(#v2_pdn_address_allocation{type = ipv4, address = Addr}) ->
        #epdg_eua{type_nr = ?GTP_PDP_ADDR_TYPE_NR_IPv4,
                  ipv4 = Addr};
gtp2_paa_to_epdg_eua(#v2_pdn_address_allocation{type = ipv6, address = Addr}) ->
        #epdg_eua{type_nr = ?GTP_PDP_ADDR_TYPE_NR_IPv6,
                  ipv6 = Addr}.
%TODO: IPv4v6

epdg_eua_to_gsup_pdp_address(#epdg_eua{type_nr = ?GTP_PDP_ADDR_TYPE_NR_IPv4, ipv4 = Addr}) ->
        #{pdp_type_org => 1,
	  pdp_type_nr => ?GTP_PDP_ADDR_TYPE_NR_IPv4,
	  address => #{ ipv4 => Addr}};

epdg_eua_to_gsup_pdp_address(#epdg_eua{type_nr = ?GTP_PDP_ADDR_TYPE_NR_IPv6, ipv6 = Addr}) ->
#{pdp_type_org => 1,
        pdp_type_nr => ?GTP_PDP_ADDR_TYPE_NR_IPv6,
        address => #{ ipv6 => Addr}}.
%TODO: IPv4v6

% 3GPP TS 23.003 clause 19
% Input: "<IMSI>@nai.epc.mnc<MNC>.mcc<MCC>.3gppnetwork.org"
% % TODO: lead number prefix
nai_to_imsi(NAI) ->
    NAIRev = string:reverse(NAI),
    ImsiRev = string:find(NAIRev, "@", trailing),
    ImsiRev2 = string:trim(ImsiRev, leading, "@"),
    string:reverse(ImsiRev2).
