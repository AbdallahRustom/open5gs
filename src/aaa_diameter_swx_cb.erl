%%
%% The diameter application callback module configured by client.erl.
%%

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


-module(aaa_diameter_swx_cb).

-include_lib("diameter/include/diameter.hrl").
-include_lib("diameter_3gpp_ts29_273_swx.hrl").
-include("conv.hrl").

%% diameter callbacks
-export([peer_up/3, peer_down/3, pick_peer/4, pick_peer/5, prepare_request/3, prepare_request/4,
         prepare_retransmit/3,  prepare_retransmit/4,
         handle_request/3,
         handle_answer/4, handle_answer/5, handle_error/4, handle_error/5]).

%% peer_up/3
peer_up(_SvcName, Peer, State) ->
    lager:info("Peer up: ~p~n", [Peer]),
    State.

%% peer_down/3
peer_down(_SvcName, Peer, State) ->
    lager:info("Peer down: ~p~n", [Peer]),
    State.

%% pick_peer/4
pick_peer([Peer | _], _, _SvcName, _State) ->
    {ok, Peer}.
pick_peer([Peer | _], _, _SvcName, _State, _ExtraPars) ->
    {ok, Peer}.

%% prepare_request/3
prepare_request(#diameter_packet{msg = [ T | Avps ]}, _, {_, Caps})
  when is_list(Avps) ->
    #diameter_caps{origin_host = {OH, DH}, origin_realm = {OR, DR}} = Caps,
    {send,
     [T,
      {'Origin-Host', OH},
      {'Origin-Realm', OR},
      {'Destination-Host', [DH]},
      {'Destination-Realm', DR}
      | Avps]}.
% TODO: is there a simple way to capture all the following requests?
prepare_request(#diameter_packet{msg = Req}, _, {_, Caps}, _ExtraPars)
		when is_record(Req, 'MAR') ->
    #diameter_caps{origin_host = {OH, DH}, origin_realm = {OR, DR}} = Caps,
	Msg = Req#'MAR'{'Origin-Host' = OH,
               'Origin-Realm' = OR,
               'Destination-Host' = [DH],
               'Destination-Realm' = DR},
	{send, Msg};
%% prepare_request/4
prepare_request(#diameter_packet{msg = Req}, _, {_, Caps}, _ExtraPars)
		when is_record(Req, 'SAR') ->
    #diameter_caps{origin_host = {OH, DH}, origin_realm = {OR, DR}} = Caps,
	Msg = Req#'SAR'{'Origin-Host' = OH,
               'Origin-Realm' = OR,
               'Destination-Host' = [DH],
               'Destination-Realm' = DR},
    lager:debug("SWx prepare_request: ~p~n", [Msg]),
	{send, Msg}.

%% prepare_retransmit/3
prepare_retransmit(Packet, SvcName, Peer) ->
    prepare_request(Packet, SvcName, Peer).

%% prepare_retransmit/4
prepare_retransmit(Packet, SvcName, Peer, ExtraPars) ->
    prepare_request(Packet, SvcName, Peer, ExtraPars).

%% handle_request/3

%% 3GPP TS 29.273 8.2.2.2 HSS Initiated Update of User Profile Procedure
handle_request(#diameter_packet{msg = Req, errors = []}, _SvcName, {_, Caps}) when is_record(Req, 'PPR') ->
    lager:info("SWx Rx PPR from ~p: ~p~n", [Caps, Req]),
    #diameter_caps{origin_host = {OH,_}, origin_realm = {OR,_}} = Caps,
    #'PPR'{'Session-Id' = SessionId,
           'Vendor-Specific-Application-Id' = VendorAppId,
           'Auth-Session-State' = AuthSessState,
           'User-Name' = Imsi,
           'Non-3GPP-User-Data' = N3UAopt} = Req,
    case aaa_ue_fsm:get_pid_by_imsi(Imsi) of
        Pid when is_pid(Pid) ->
            PGWAddresses = parse_pgw_addr_from_N3UA(N3UAopt),
            aaa_ue_fsm:ev_rx_swx_ppr(Pid, {PGWAddresses}),
            Res = 2001, %% Success
            ERes = [];
        undefined ->
            Res = [],
            %% TS 29.229 6.2.2.1 DIAMETER_ERROR_USER_UNKNOWN
            ERes = #'Experimental-Result'{'Vendor-Id' = ?VENDOR_ID_3GPP,
                                          'Experimental-Result-Code' = 5001}
    end,
    Resp = #'PPA'{'Session-Id' = SessionId,
                  'Vendor-Specific-Application-Id' = VendorAppId,
                  'Result-Code' = Res,
                  'Experimental-Result' = ERes,
                  'Auth-Session-State' = AuthSessState,
                  'Origin-Host' = OH,
                  'Origin-Realm' = OR},
    lager:info("SWx Tx to ~p: ~p~n", [Caps, Resp]),
    {reply, Resp};

%% 3GPP TS 29.273 8.2.2.4 Network Initiated De-Registration by HSS Procedure
handle_request(#diameter_packet{msg = Req, errors = []}, _SvcName, {_, Caps}) when is_record(Req, 'RTR') ->
    lager:info("SWx Rx RTR from ~p: ~p~n", [Caps, Req]),
    #diameter_caps{origin_host = {OH,_}, origin_realm = {OR,_}} = Caps,
    #'RTR'{'Session-Id' = SessionId,
           'Vendor-Specific-Application-Id' = VendorAppId,
           'Auth-Session-State' = AuthSessState,
           'User-Name' = Imsi,
           'Deregistration-Reason' = DeregReason} = Req,
    case aaa_ue_fsm:get_pid_by_imsi(Imsi) of
        Pid when is_pid(Pid) ->
            case DeregReason of
                #'Deregistration-Reason'{'Reason-Code' = ?'REASON-CODE_PERMANENT_TERMINATION'} ->
                    case aaa_ue_fsm:ev_rx_swx_rtr(Pid) of
                        {error, _} -> aaa_ue_fsm:stop(Pid);
                        _ -> ok
                    end;
                _ ->
                    aaa_ue_fsm:stop(Pid)
            end,
            Res = 2001, %% Success
            ERes = [];
        undefined ->
            Res = [],
            %% TS 29.229 6.2.2.1 DIAMETER_ERROR_USER_UNKNOWN
            ERes = #'Experimental-Result'{'Vendor-Id' = ?VENDOR_ID_3GPP,
                                          'Experimental-Result-Code' = 5001}
    end,
    Resp = #'RTA'{'Session-Id' = SessionId,
                  'Vendor-Specific-Application-Id' = VendorAppId,
                  'Result-Code' = Res,
                  'Experimental-Result' = ERes,
                  'Auth-Session-State' = AuthSessState,
                  'Origin-Host' = OH,
                  'Origin-Realm' = OR},
    lager:info("SWx Tx to ~p: ~p~n", [Caps, Resp]),
    {reply, Resp};

handle_request(Msg, _SvcName, Peer) ->
    lager:error("SWx Rx unexpected msg from ~p: ~p~n", [Peer, Msg]),
    erlang:error({unexpected, ?MODULE, ?LINE}).

%% handle_answer/4
handle_answer(#diameter_packet{msg = Msg, errors = Errors}, _Request, _SvcName, Peer, ReqPid) when is_record(Msg, 'MAA')  ->
    lager:info("SWx Rx MAA ~p: ~p/ Errors ~p ~n", [Peer, Msg, Errors]),
    #'MAA'{'Result-Code' = ResultCodeOpt,
           'Experimental-Result' = ExperimentalResultOpt} = Msg,
    DiaRC = parse_epdg_dia_rc(ResultCodeOpt, ExperimentalResultOpt),
    case conv:dia_rc_success(DiaRC) of
    ok ->
        #'MAA'{'SIP-Auth-Data-Item' = SipAuthTuples} = Msg,
        AuthTuples = lists:map(fun dia_sip2epdg_auth_tuple/1, SipAuthTuples),
        aaa_ue_fsm:ev_rx_swx_maa(ReqPid, {ok, AuthTuples});
    _ ->
        aaa_ue_fsm:ev_rx_swx_maa(ReqPid, {error, DiaRC})
    end,
    {ok, Msg};

handle_answer(#diameter_packet{msg = Msg, errors = Errors}, Request, _SvcName, Peer, ReqPid) when is_record(Msg, 'SAA')  ->
    lager:info("SWx Rx SAA ~p: ~p/ Errors ~p ~n", [Peer, Msg, Errors]),
    % Recover fields from originating request:
    #'SAR'{'Server-Assignment-Type' = SAType} = Request,
    % Retrieve fields from answer:
    #'SAA'{'Result-Code' = ResultCodeOpt,
           'Experimental-Result' = ExperimentalResultOpt} = Msg,
    DiaRC = parse_epdg_dia_rc(ResultCodeOpt, ExperimentalResultOpt),
    case conv:dia_rc_success(DiaRC) of
    ok ->
        #'SAA'{'Non-3GPP-User-Data' = N3UA} = Msg,
        PGWAddresses = parse_pgw_addr_from_N3UA(N3UA),
        case PGWAddresses of
        undefined -> ResInfo = #{};
        _ -> ResInfo = maps:put(pgw_address_list, PGWAddresses, #{})
        end,
        aaa_ue_fsm:ev_rx_swx_saa(ReqPid, {ok, SAType, ResInfo});
    _ ->
        aaa_ue_fsm:ev_rx_swx_saa(ReqPid, {error, SAType, DiaRC})
    end,
    {ok, Msg}.

handle_answer(#diameter_packet{msg = Msg, errors = []}, _Request, _SvcName, Peer) ->
    lager:info("SWx Rx ~p: ~p~n", [Peer, Msg]),
    {ok, Msg};

handle_answer(#diameter_packet{msg = Msg, errors = Errors}, _Request, _SvcName, Peer) ->
    lager:info("SWx Rx ~p: ~p / Errors ~p ~n", [Peer, Msg, Errors]),
    {error, Errors}.

%% handle_error/4
handle_error(Reason, Request, _SvcName, _Peer) when is_list(Request) ->
    lager:error("SWx error: ~p~n", [Reason]),
    {error, Reason};
handle_error(Reason, _Request, _SvcName, _Peer) ->
    lager:error("SWx error: ~p~n", [Reason]),
    {error, Reason}.
%% handle_error/5
handle_error(Reason, _Request, _SvcName, _Peer, ExtraPars) ->
    lager:error("SWx error: ~p, ExtraPars: ~p~n", [Reason, ExtraPars]),
    {error, Reason}.

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

parse_epdg_dia_rc([], []) ->
    #epdg_dia_rc{vendor_id = undefined, result_code = 2001 };
parse_epdg_dia_rc([ResultCode], []) ->
    #epdg_dia_rc{vendor_id = undefined, result_code = ResultCode };
parse_epdg_dia_rc([], [ExpResultCode]) ->
    #'Experimental-Result'{'Vendor-Id' = VendorId, 'Experimental-Result-Code' = ERC} = ExpResultCode,
    #epdg_dia_rc{vendor_id = VendorId, result_code = ERC };
parse_epdg_dia_rc([ResultCode], [_ExpResultCode]) ->
    parse_epdg_dia_rc([ResultCode], []).

dia_sip2epdg_auth_tuple(#'SIP-Auth-Data-Item'{'SIP-Authenticate' = [Authenticate],
                                              'SIP-Authorization' = [Authorization],
                                              'Confidentiality-Key' = [CKey],
                                              'Integrity-Key' = [IKey]}) ->
    lager:info("dia_sip2gsup: auth ~p authz ~p ~n", [Authenticate, Authorization]),
    lager:info("  rand ~p autn ~p ~n", [lists:sublist(Authenticate, 1, 16), lists:sublist(Authenticate, 17, 16)]),
    #epdg_auth_tuple{
        rand = list_to_binary(lists:sublist(Authenticate, 1, 16)),
        autn = list_to_binary(lists:sublist(Authenticate, 17, 16)),
        res = list_to_binary(Authorization),
        ik = list_to_binary(IKey),
        ck =list_to_binary(CKey)
    }.

parse_pgw_addr_from_MIP6_Agent_Info([]) ->
    undefined;
parse_pgw_addr_from_MIP6_Agent_Info([AgentInfo]) ->
    #'MIP6-Agent-Info'{'MIP-Home-Agent-Address' = AgentAddrOpt} = AgentInfo,
    case AgentAddrOpt of
    [] -> undefined;
    Res -> Res
    end.
parse_pgw_addr_from_APN_Configuration([]) ->
    undefined;
parse_pgw_addr_from_APN_Configuration([Head | Tail] = _ApnConfigs) ->
    #'APN-Configuration'{'MIP6-Agent-Info' = AgentInfoOpt} = Head,
    case parse_pgw_addr_from_MIP6_Agent_Info(AgentInfoOpt) of
    undefined -> parse_pgw_addr_from_APN_Configuration(Tail);
    Res -> Res
    end.
parse_pgw_addr_from_N3UA([]) ->
    undefined;
parse_pgw_addr_from_N3UA([N3UA]) ->
    #'Non-3GPP-User-Data'{'APN-Configuration' = ApnConfigs} = N3UA,
    parse_pgw_addr_from_APN_Configuration(ApnConfigs).
