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

-module(gtp_utils).
-author('Alexander Couzens <lynxis@fe80.eu>').

-include_lib("gtp_utils.hrl").

-export([plmn_to_bin/3, enum_v2_cause/1, v2_cause_successful/1]).


% ergw/apps/ergw/test/*.erl
% under GPLv2+
plmn_to_bin(CC, NC, NCSize) ->
    MCC = iolist_to_binary(io_lib:format("~3..0b", [CC])),
    MNC = iolist_to_binary(io_lib:format("~*..0b", [NCSize, NC])),
    {MCC, MNC}.

enum_v2_cause(reserved) -> 1;
enum_v2_cause(local_detach) -> 2;
enum_v2_cause(complete_detach) -> 3;
enum_v2_cause(rat_changed_from_3gpp_to_non_3gpp) -> 4;
enum_v2_cause(isr_deactivation) -> 5;
enum_v2_cause(error_indication_received_from_rnc_enodeb_s4_sgsn) -> 6;
enum_v2_cause(imsi_detach_only) -> 7;
enum_v2_cause(reactivation_requested) -> 8;
enum_v2_cause(pdn_reconnection_to_this_apn_disallowed) -> 9;
enum_v2_cause(access_changed_from_non_3gpp_to_3gpp) -> 10;
enum_v2_cause(pdn_connection_inactivity_timer_expires) -> 11;
enum_v2_cause(pgw_not_responding) -> 12;
enum_v2_cause(network_failure) -> 13;
enum_v2_cause(qos_parameter_mismatch) -> 14;
enum_v2_cause(request_accepted) -> 16;
enum_v2_cause(request_accepted_partially) -> 17;
enum_v2_cause(new_pdn_type_due_to_network_preference) -> 18;
enum_v2_cause(new_pdn_type_due_to_single_address_bearer_only) -> 19;
enum_v2_cause(context_not_found) -> 64;
enum_v2_cause(invalid_message_format) -> 65;
enum_v2_cause(version_not_supported_by_next_peer) -> 66;
enum_v2_cause(invalid_length) -> 67;
enum_v2_cause(service_not_supported) -> 68;
enum_v2_cause(mandatory_ie_incorrect) -> 69;
enum_v2_cause(mandatory_ie_missing) -> 70;
enum_v2_cause(system_failure) -> 72;
enum_v2_cause(no_resources_available) -> 73;
enum_v2_cause(semantic_error_in_the_tft_operation) -> 74;
enum_v2_cause(syntactic_error_in_the_tft_operation) -> 75;
enum_v2_cause(semantic_errors_in_packet_filter) -> 76;
enum_v2_cause(syntactic_errors_in_packet_filter) -> 77;
enum_v2_cause(missing_or_unknown_apn) -> 78;
enum_v2_cause(gre_key_not_found) -> 80;
enum_v2_cause(relocation_failure) -> 81;
enum_v2_cause(denied_in_rat) -> 82;
enum_v2_cause(preferred_pdn_type_not_supported) -> 83;
enum_v2_cause(all_dynamic_addresses_are_occupied) -> 84;
enum_v2_cause(ue_context_without_tft_already_activated) -> 85;
enum_v2_cause(protocol_type_not_supported) -> 86;
enum_v2_cause(ue_not_responding) -> 87;
enum_v2_cause(ue_refuses) -> 88;
enum_v2_cause(service_denied) -> 89;
enum_v2_cause(unable_to_page_ue) -> 90;
enum_v2_cause(no_memory_available) -> 91;
enum_v2_cause(user_authentication_failed) -> 92;
enum_v2_cause(apn_access_denied___no_subscription) -> 93;
enum_v2_cause(request_rejected) -> 94;
enum_v2_cause(p_tmsi_signature_mismatch) -> 95;
enum_v2_cause(imsi_imei_not_known) -> 96;
enum_v2_cause(semantic_error_in_the_tad_operation) -> 97;
enum_v2_cause(syntactic_error_in_the_tad_operation) -> 98;
enum_v2_cause(remote_peer_not_responding) -> 100;
enum_v2_cause(collision_with_network_initiated_request) -> 101;
enum_v2_cause(unable_to_page_ue_due_to_suspension) -> 102;
enum_v2_cause(conditional_ie_missing) -> 103;
enum_v2_cause(apn_restriction_type_incompatible_with_currently_active_pdn_connection) -> 104;
enum_v2_cause(invalid_overall_length_of_the_triggered_response_message_and_a_piggybacked_initial_message) -> 105;
enum_v2_cause(data_forwarding_not_supported) -> 106;
enum_v2_cause(invalid_reply_from_remote_peer) -> 107;
enum_v2_cause(fallback_to_gtpv1) -> 108;
enum_v2_cause(invalid_peer) -> 109;
enum_v2_cause(temporarily_rejected_due_to_handover_tau_rau_procedure_in_progress) -> 110;
enum_v2_cause(modifications_not_limited_to_s1_u_bearers) -> 111;
enum_v2_cause(request_rejected_for_a_pmipv6_reason) -> 112;
enum_v2_cause(apn_congestion) -> 113;
enum_v2_cause(bearer_handling_not_supported) -> 114;
enum_v2_cause(ue_already_re_attached) -> 115;
enum_v2_cause(multiple_pdn_connections_for_a_given_apn_not_allowed) -> 116;
enum_v2_cause(target_access_restricted_for_the_subscriber) -> 117;
enum_v2_cause(mme_sgsn_refuses_due_to_vplmn_policy) -> 119;
enum_v2_cause(gtp_c_entity_congestion) -> 120;
enum_v2_cause(late_overlapping_request) -> 121;
enum_v2_cause(timed_out_request) -> 122;
enum_v2_cause(ue_is_temporarily_not_reachable_due_to_power_saving) -> 123;
enum_v2_cause(relocation_failure_due_to_nas_message_redirection) -> 124;
enum_v2_cause(ue_not_authorised_by_ocs_or_external_aaa_server) -> 125;
enum_v2_cause(multiple_accesses_to_a_pdn_connection_not_allowed) -> 126;
enum_v2_cause(request_rejected_due_to_ue_capability) -> 127;
enum_v2_cause(s1_u_path_failure) -> 128;
enum_v2_cause('5gc_not_allowed') -> 129.


-spec v2_cause_successful(integer()) -> boolean().

v2_cause_successful(GtpCauseInt) ->
    GtpCauseInt == ?GTP2_CAUSE_REQUEST_ACCEPTED orelse
    GtpCauseInt == ?GTP2_CAUSE_REQUEST_ACCEPTED_PARTIALLY orelse
    GtpCauseInt == ?GTP2_CAUSE_NEW_PDN_TYPE_DUE_TO_NETWORK_PREFERENCE orelse
    GtpCauseInt == ?GTP2_CAUSE_NEW_PDN_TYPE_DUE_TO_SINGLE_ADDRESS_BEARER_ONLY.
