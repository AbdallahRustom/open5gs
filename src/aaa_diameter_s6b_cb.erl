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
pick_peer([_Peer | _], _, _SvcName, _State) ->
    ?UNEXPECTED.

%% prepare_request/3

prepare_request(_, _SvcName, _Peer) ->
	?UNEXPECTED.

%% prepare_retransmit/3
prepare_retransmit(_Packet, _SvcName, _Peer) ->
	?UNEXPECTED.

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
           'User-Name' = UserName} = Req,
    Result = aaa_diameter_swx:server_assignment_request(UserName, 1, "internet"),
    case Result of
            {ok, _} ->
                    ResultCode = 2001;
            {error, _Err} ->
                ResultCode = ?'RULE-FAILURE-CODE_CM_AUTHORIZATION_REJECTED'
    end,
    Resp = #'AAA'{'Session-Id'=SessionId,
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
           'User-Name' = _UserNameOpt} = Req,
    % 3GPP TS 29.273 9.2.2.3.2 Session-Termination-Answer (STA) Command:
    Resp = #'STA'{'Session-Id' = SessionId,
                  'Result-Code' = 2001,
                  'Origin-Host' = OH,
                  'Origin-Realm' = OR},
    lager:info("S6b Tx to ~p: ~p~n", [Caps, Resp]),
    {reply, Resp};

handle_request(Packet, _SvcName, Peer) ->
    lager:error("S6b Rx unexpected msg from ~p: ~p~n", [Peer, Packet]),
    erlang:error({unexpected, ?MODULE, ?LINE}).
