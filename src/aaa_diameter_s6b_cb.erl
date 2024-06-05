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


-module(aaa_diameter_s6b_cb).

-include_lib("diameter/include/diameter.hrl").
-include_lib("diameter_3gpp_ts29_273_s6b.hrl").

-include("conv.hrl").

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
prepare_request(#diameter_packet{msg = [ T | Avps ]}, _, {_, Caps})
  when is_list(Avps) ->
    #diameter_caps{origin_host = {OH, DH}, origin_realm = {OR, DR}} = Caps,
    {send,
     [T,
      {'Origin-Host', OH},
      {'Origin-Realm', OR},
      {'Destination-Host', [DH]},
      {'Destination-Realm', DR}
      | Avps]};
% TODO: is there a simple way to capture all the following requests?
prepare_request(#diameter_packet{msg = Req}, _, {_, Caps})
		when is_record(Req, 'RAR') ->
    #diameter_caps{origin_host = {OH, DH}, origin_realm = {OR, DR}} = Caps,
	Msg = Req#'RAR'{'Origin-Host' = OH,
                    'Origin-Realm' = OR,
                    'Destination-Realm' = DR,
                    'Destination-Host' = DH},
    lager:debug("S6b prepare_request: ~p~n", [Msg]),
	{send, Msg};
prepare_request(#diameter_packet{msg = Req}, _, {_, Caps})
		when is_record(Req, 'ASR') ->
    #diameter_caps{origin_host = {OH, DH}, origin_realm = {OR, DR}} = Caps,
	Msg = Req#'ASR'{'Origin-Host' = OH,
                    'Origin-Realm' = OR,
                    'Destination-Realm' = DR,
                    'Destination-Host' = DH},
    lager:debug("S6b prepare_request: ~p~n", [Msg]),
	{send, Msg}.

%% prepare_retransmit/3
prepare_retransmit(Packet, SvcName, Peer) ->
    prepare_request(Packet, SvcName, Peer).

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
           'User-Name' = [NAI],
           'Service-Selection' = [Apn],
           'MIP6-Agent-Info' = AgentInfoOpt } = Req,
    Imsi = conv:nai_to_imsi(NAI),
    PidRes = aaa_ue_fsm:get_pid_by_imsi(Imsi),
    case PidRes of
    PidRes when is_pid(PidRes) ->
        ok = aaa_ue_fsm:ev_rx_s6b_aar(PidRes, {NAI, Apn, AgentInfoOpt}),
        lager:debug("Waiting for S6b AAA~n", []),
        receive
            {aaa, DiaRC} -> lager:debug("Rx AAA with DiaRC=~p~n", [DiaRC])
        end;
    undefined -> lager:error("Error looking up FSM for IMSI~n", [Imsi]),
         DiaRC = #epdg_dia_rc{result_code = ?'RULE-FAILURE-CODE_CM_AUTHORIZATION_REJECTED'}
    end,
    Resp = #'AAA'{'Session-Id'= SessionId,
                  'Auth-Application-Id' = AuthAppId,
                  'Auth-Request-Type' = AuthReqType,
                  'Result-Code' = DiaRC#epdg_dia_rc.result_code,
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
    PidRes = aaa_ue_fsm:get_pid_by_imsi(UserName),
    case PidRes of
    PidRes when is_pid(PidRes) ->
        case aaa_ue_fsm:ev_rx_s6b_str(PidRes) of
        ok ->
            lager:debug("Waiting for S6b STA~n", []),
            receive
                {sta, DiaRC} ->
                    ResultCode = DiaRC#epdg_dia_rc.result_code,
                    lager:debug("Rx STA with ResultCode=~p~n", [ResultCode])
            end;
        {ok, DiaRC} ->
            ResultCode = DiaRC#epdg_dia_rc.result_code;
        {error, Err} when is_integer(Err) ->
            ResultCode = Err;
        {error, _} ->
            ResultCode = ?'RULE-FAILURE-CODE_CM_AUTHORIZATION_REJECTED'
        end;
    undefined -> lager:error("Error looking up FSM for IMSI~n", [UserName]),
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

%% handle_answer/4
handle_answer(#diameter_packet{msg = Msg, errors = Errors}, Request, _SvcName, Peer) when is_record(Msg, 'RAA')  ->
    lager:info("S6b Rx RAA ~p: ~p/ Errors ~p ~n", [Peer, Msg, Errors]),
    % Obtain Imsi from originating Request:
    #'RAR'{'User-Name' = [NAI]} = Request,
    Imsi = conv:nai_to_imsi(NAI),
    PidRes = aaa_ue_fsm:get_pid_by_imsi(Imsi),
    #'RAA'{'Result-Code' = ResultCode} = Msg,
    DiaRC = #epdg_dia_rc{result_code = ResultCode},
    case conv:dia_rc_success(DiaRC) of
    ok ->
        aaa_ue_fsm:ev_rx_s6b_raa(PidRes, ok);
    _ ->
        aaa_ue_fsm:ev_rx_s6b_raa(PidRes, {error, DiaRC})
    end,
    {ok, Msg};

handle_answer(#diameter_packet{msg = Msg, errors = Errors}, Request, _SvcName, Peer) when is_record(Msg, 'ASA')  ->
    lager:info("S6b Rx ASA ~p: ~p/ Errors ~p ~n", [Peer, Msg, Errors]),
    % Obtain Imsi from originating Request:
    #'ASR'{'User-Name' = [NAI]} = Request,
    Imsi = conv:nai_to_imsi(NAI),
    PidRes = aaa_ue_fsm:get_pid_by_imsi(Imsi),
    #'ASA'{'Result-Code' = ResultCode} = Msg,
    DiaRC = #epdg_dia_rc{result_code = ResultCode},
    case conv:dia_rc_success(DiaRC) of
    ok ->
        aaa_ue_fsm:ev_rx_s6b_asa(PidRes, ok);
    _ ->
        aaa_ue_fsm:ev_rx_s6b_asa(PidRes, {error, DiaRC})
    end,
    {ok, Msg};

handle_answer(#diameter_packet{msg = Msg, errors = []}, _Request, _SvcName, Peer) ->
    lager:notice("S6b Rx unexpected ~p: ~p~n", [Peer, Msg]),
    {ok, Msg}.
