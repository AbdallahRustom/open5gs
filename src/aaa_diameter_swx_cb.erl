%%
%% The diameter application callback module configured by client.erl.
%%
-module(aaa_diameter_swx_cb).

-include_lib("diameter/include/diameter.hrl").
-include_lib("diameter_3gpp_ts29_273_swx.hrl").
-include("conv.hrl").

%% diameter callbacks
-export([peer_up/3, peer_down/3, pick_peer/4, pick_peer/5, prepare_request/3, prepare_request/4,
         prepare_retransmit/3,  prepare_retransmit/4,
         handle_answer/4, handle_answer/5, handle_error/4, handle_error/5, handle_request/3]).

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

%% handle_answer/4
handle_answer(#diameter_packet{msg = Msg, errors = Errors}, _Request, _SvcName, Peer, ReqPid) when is_record(Msg, 'MAA')  ->
    lager:info("SWx Rx MAA ~p: ~p/ Errors ~p ~n", [Peer, Msg, Errors]),
    #'MAA'{'Result-Code' = ResultCodeOpt,
           'Experimental-Result' = ExperimentalResultOpt} = Msg,
    DiaRC = parse_epdg_dia_rc(ResultCodeOpt, ExperimentalResultOpt),
    case dia_rc_success(DiaRC) of
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
    case dia_rc_success(DiaRC) of
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

%% handle_request/3
handle_request(_Packet, _SvcName, _Peer) ->
    erlang:error({unexpected, ?MODULE, ?LINE}).

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

dia_rc_success(#epdg_dia_rc{result_code = 2001}) -> ok;
dia_rc_success(#epdg_dia_rc{result_code = 2002}) -> ok;
dia_rc_success(_) -> invalid_result_code.

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