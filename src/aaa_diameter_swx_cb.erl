%%
%% The diameter application callback module configured by client.erl.
%%
-module(aaa_diameter_swx_cb).

-include_lib("diameter/include/diameter.hrl").
-include_lib("diameter_3gpp_ts29_273_swx.hrl").

%% diameter callbacks
-export([peer_up/3, peer_down/3, pick_peer/4, pick_peer/5, prepare_request/3, prepare_request/4,
         prepare_retransmit/3,  prepare_retransmit/4,
         handle_answer/4, handle_answer/5, handle_error/4, handle_request/3]).

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
    aaa_ue_fsm:ev_rx_swx_maa(ReqPid, Msg),
    {ok, Msg};
handle_answer(#diameter_packet{msg = Msg, errors = Errors}, _Request, _SvcName, Peer, ReqPid) when is_record(Msg, 'SAA')  ->
    lager:info("SWx Rx SAA ~p: ~p/ Errors ~p ~n", [Peer, Msg, Errors]),
    #'SAA'{'Result-Code' = [ResultCode]} = Msg,
    aaa_ue_fsm:ev_rx_swx_saa(ReqPid, ResultCode),
    {ok, Msg}.
handle_answer(#diameter_packet{msg = Msg, errors = []}, _Request, _SvcName, Peer) ->
    lager:info("SWx Rx ~p: ~p~n", [Peer, Msg]),
    {ok, Msg};
handle_answer(#diameter_packet{msg = Msg, errors = Errors}, _Request, _SvcName, Peer) ->
    lager:info("SWx Rx ~p: ~p / Errors ~p ~n", [Peer, Msg, Errors]),
    {error, Errors}.

%% handle_error/4
handle_error(Reason, Request, _SvcName, _Peer) when is_list(Request) ->
    lager:error("error: ~p~n", [Reason]),
    {error, Reason};
handle_error(Reason, _Request, _SvcName, _Peer) ->
    lager:error("error: ~p~n", [Reason]),
    {error, Reason}.

%% handle_request/3
handle_request(_Packet, _SvcName, _Peer) ->
    erlang:error({unexpected, ?MODULE, ?LINE}).
