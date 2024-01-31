%%
%% The diameter application callback module configured by client.erl.
%%
-module(aaa_diameter_s6b_cb).

-include_lib("diameter/include/diameter.hrl").
-include_lib("diameter_3gpp_ts29_273_s6b.hrl").

%% diameter callbacks
-export([peer_up/3, peer_down/3, pick_peer/4, prepare_request/3, prepare_retransmit/3,
         handle_answer/4, handle_error/4, handle_request/3]).

-define(UNEXPECTED, erlang:error({unexpected, ?MODULE, ?LINE})).

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

%% prepare_request/3
prepare_request(_Req, _SvcName, _Peer) ->
    lager:error("Unexpected prepare_request(): ~p~n", [_Req]),
    ?UNEXPECTED.

%% prepare_retransmit/3
prepare_retransmit(Packet, SvcName, Peer) ->
    prepare_request(Packet, SvcName, Peer).

%% handle_answer/4

%% Since client.erl has detached the call when using the list
%% encoding and not otherwise, output to the terminal in the
%% the former case, return in the latter.

handle_answer(_Packet, _Request, _SvcName, _Peer) ->
    ?UNEXPECTED.

%% handle_error/4
handle_error(Reason, Request, _SvcName, _Peer) when is_list(Request) ->
    lager:error("Request error: ~p~n", [Reason]),
    ?UNEXPECTED.

% 3GPP TS 29.273 9.1.2.2
handle_request(#diameter_packet{msg = Req, errors = []}, _SvcName, {_, Caps}) when is_record(Req, 'AAR') ->
    lager:info("S6b Rx from ~p: ~p~n", [Caps, Req]),
	% extract relevant fields from DIAMETER AAR
	#diameter_caps{origin_host = {OH,_}, origin_realm = {OR,_}} = Caps,
	#'AAR'{'Session-Id' = SessionId,
           'Auth-Application-Id' = AuthAppId,
           'Auth-Request-Type' = AuthReqType,
           'User-Name' = [UserName],
           'Service-Selection' = [Apn]} = Req,
    Result = aaa_diameter_swm:get_ue_fsm_by_imsi(UserName),
    case Result of
    {ok, Pid} ->
        ok = aaa_ue_fsm:ev_rx_s6b_aar(Pid, Apn),
        lager:debug("Waiting for S6b AAA~n", []),
        receive
            {aaa, ResultCode} -> lager:debug("Rx AAA with ResultCode=~p~n", [ResultCode])
        end;
    _ -> lager:error("Error looking up FSM for IMSI~n", [UserName]),
         ResultCode = ?'RULE-FAILURE-CODE_CM_AUTHORIZATION_REJECTED'
    end,
    Resp = #'AAA'{'Session-Id'= SessionId,
                  'Auth-Application-Id' = AuthAppId,
                  'Auth-Request-Type' = AuthReqType,
                  'Result-Code' = ResultCode,
                  'Origin-Host' = OH,
                  'Origin-Realm' = OR},
    lager:info("S6b Tx to ~p: ~p~n", [Caps, Resp]),
    {reply, Resp};

% 3GPP TS 29.273 9.2.2.3.1 Session-Termination-Request (STR) Command:
handle_request(#diameter_packet{msg = Req, errors = []}, _SvcName, {_, Caps}) when is_record(Req, 'STR') ->
    lager:info("S6b Rx from ~p: ~p~n", [Caps, Req]),
    % extract relevant fields from DIAMETER STR:
    #diameter_caps{origin_host = {OH,_}, origin_realm = {OR,_}} = Caps,
    #'STR'{'Session-Id' = SessionId,
           'Auth-Application-Id' = _AuthAppId,
           'Termination-Cause' = _TermCause,
           'User-Name' = [UserName]} = Req,
    Result = aaa_diameter_swm:get_ue_fsm_by_imsi(UserName),
    case Result of
    {ok, Pid} ->
        case aaa_ue_fsm:ev_rx_s6b_str(Pid) of
        ok ->
            lager:debug("Waiting for S6b STA~n", []),
            receive
                {sta, ResultCode} -> lager:debug("Rx STA with ResultCode=~p~n", [ResultCode])
            end;
        {ok, DiaRC} when is_integer(DiaRC) ->
            ResultCode = DiaRC;
        {error, Err} when is_integer(Err) ->
            ResultCode = Err;
        {error, _} ->
            ResultCode = ?'RULE-FAILURE-CODE_CM_AUTHORIZATION_REJECTED'
        end;
    _ -> lager:error("Error looking up FSM for IMSI~n", [UserName]),
        ResultCode = ?'RULE-FAILURE-CODE_CM_AUTHORIZATION_REJECTED'
    end,
    % 3GPP TS 29.273 9.2.2.3.2 Session-Termination-Answer (STA) Command:
    Resp = #'STA'{'Session-Id' = SessionId,
                  'Result-Code' = ResultCode,
                  'Origin-Host' = OH,
                  'Origin-Realm' = OR},
    lager:info("S6b Tx to ~p: ~p~n", [Caps, Resp]),
    {reply, Resp};

handle_request(Packet, _SvcName, Peer) ->
    lager:error("S6b Rx unexpected msg from ~p: ~p~n", [Peer, Packet]),
    erlang:error({unexpected, ?MODULE, ?LINE}).
