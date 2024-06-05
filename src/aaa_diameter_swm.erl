% AAA Server implementation of SWm Diameter interface, TS 29.273 section 7
% This interface is so far implemented through internal erlang messages against
% the internal ePDG.

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


-module(aaa_diameter_swm).
-behaviour(gen_server).

-include_lib("diameter_3gpp_ts29_273.hrl").

-record(swm_state, {
	table_id % ets table id
}).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).
-export([code_change/3, terminate/2]).

-export([rx_der_auth_request/4,
	 rx_der_auth_compl_request/2,
	 rx_reauth_answer/2,
	 rx_auth_request/1,
	 rx_session_termination_request/1,
	 rx_abort_session_answer/1]).
-export([tx_dea_auth_response/2,
	 tx_dea_auth_compl_response/2,
	 tx_reauth_request/1,
	 tx_session_termination_answer/2,
	 tx_as_request/1]).

-define(SERVER, ?MODULE).

start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
	TableId = ets:new(auth_req, [bag, named_table]),
	{ok, #swm_state{table_id = TableId}}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Tx over emulated SWm wire:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

tx_dea_auth_response(Imsi, Result) ->
	_Result = gen_server:call(?SERVER, {dea_auth_resp, Imsi, Result}).

tx_dea_auth_compl_response(Imsi, Result) ->
	_Result = gen_server:call(?SERVER, {dea_auth_compl_resp, Imsi, Result}).

tx_reauth_request(Imsi) ->
	_Result = gen_server:call(?SERVER, {rar, Imsi}).

tx_session_termination_answer(Imsi, Result) ->
	_Result = gen_server:call(?SERVER, {sta, Imsi, Result}).

tx_as_request(Imsi) ->
	_result = gen_server:call(?SERVER, {asr, Imsi}).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Rx from emulated SWm wire:
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
rx_der_auth_request(Imsi, PdpTypeNr, Apn, EAP) ->
	gen_server:cast(?SERVER, {der_auth_req, Imsi, PdpTypeNr, Apn, EAP}).

rx_der_auth_compl_request(Imsi, Apn) ->
	gen_server:cast(?SERVER, {der_auth_compl_req, Imsi, Apn}).

rx_reauth_answer(Imsi, Result) ->
	gen_server:cast(?SERVER, {raa, Imsi, Result}).

% 3GPP TS 29.273 7.2.2.1.3 Diameter-AA-Request (AAR) Command
rx_auth_request(Imsi) ->
	gen_server:cast(?SERVER, {aar, Imsi}).

rx_session_termination_request(Imsi) ->
	gen_server:cast(?SERVER, {str, Imsi}).

rx_abort_session_answer(Imsi) ->
	gen_server:cast(?SERVER, {asa, Imsi}).

%% handle_cast: Rx side

handle_cast({der_auth_req, Imsi, PdpTypeNr, Apn, EAP}, State) ->
	case aaa_ue_fsm:get_pid_by_imsi(Imsi) of
		undefined -> {ok, Pid} = aaa_ue_fsm:start(Imsi);
		Pid -> Pid
	end,
	aaa_ue_fsm:ev_rx_swm_der_auth_req(Pid, {PdpTypeNr, Apn, EAP}),
	{noreply, State};

handle_cast({der_auth_compl_req, Imsi, Apn}, State) ->
	case aaa_ue_fsm:get_pid_by_imsi(Imsi) of
	Pid when is_pid(Pid) ->
		aaa_ue_fsm:ev_rx_swm_der_auth_compl(Pid, Apn);
	undefined ->
		RC_USER_UNKNOWN=5030,
		epdg_diameter_swm:rx_dea_auth_compl_response(Imsi, {error, RC_USER_UNKNOWN})
	end,
	{noreply, State};

handle_cast({raa, Imsi, Result}, State) ->
	case aaa_ue_fsm:get_pid_by_imsi(Imsi) of
	Pid when is_pid(Pid) -> aaa_ue_fsm:ev_rx_swm_reauth_answer(Pid, Result);
	undefined -> ok
	end,
	{noreply, State};

handle_cast({aar, Imsi}, State) ->
	case aaa_ue_fsm:get_pid_by_imsi(Imsi) of
	Pid when is_pid(Pid) ->
		case aaa_ue_fsm:ev_rx_swm_auth_request(Pid) of
		ok ->
			epdg_diameter_swm:rx_auth_answer(Imsi, ok);
		_ ->
			RC_UNABLE_TO_COMPLY=5012,
			epdg_diameter_swm:rx_auth_answer(Imsi, {error, RC_UNABLE_TO_COMPLY})
		end;
	undefined ->
		RC_USER_UNKNOWN=5030,
		epdg_diameter_swm:rx_auth_answer(Imsi, {error, RC_USER_UNKNOWN})
	end,
	{noreply, State};

handle_cast({str, Imsi}, State) ->
	case aaa_ue_fsm:get_pid_by_imsi(Imsi) of
	Pid when is_pid(Pid) ->
		case aaa_ue_fsm:ev_rx_swm_str(Pid) of
		ok -> ok; % Answering delayed due to SAR+SAA towards HSS.
		{ok, DiaRC} when is_integer(DiaRC) ->
			ok = epdg_diameter_swm:rx_session_termination_answer(Imsi, DiaRC);
		{error, Err} when is_integer(Err) ->
			ok = epdg_diameter_swm:rx_session_termination_answer(Imsi, Err);
		{error, _} ->
			ok = epdg_diameter_swm:rx_session_termination_answer(Imsi, ?'RULE-FAILURE-CODE_CM_AUTHORIZATION_REJECTED')
		end;
	undefined ->
		ok = epdg_diameter_swm:rx_session_termination_answer(Imsi, ?'RULE-FAILURE-CODE_CM_AUTHORIZATION_REJECTED')
	end,
	{noreply, State};

handle_cast({asa, Imsi}, State) ->
	case aaa_ue_fsm:get_pid_by_imsi(Imsi) of
	Pid when is_pid(Pid) ->
		aaa_ue_fsm:ev_rx_swm_asa(Pid);
	undefined ->
		ok
	end,
	{noreply, State};

handle_cast(Info, S) ->
	error_logger:error_report(["unknown handle_cast", {module, ?MODULE}, {info, Info}, {state, S}]),
	{noreply, S}.

handle_info(Info, S) ->
	error_logger:error_report(["unknown handle_info", {module, ?MODULE}, {info, Info}, {state, S}]),
	{noreply, S}.

%% handle_call: Tx side
handle_call({dea_auth_resp, Imsi, Result}, _From, State) ->
	epdg_diameter_swm:rx_dea_auth_response(Imsi, Result),
	{reply, ok, State};

handle_call({dea_auth_compl_resp, Imsi, Result}, _From, State) ->
	epdg_diameter_swm:rx_dea_auth_compl_response(Imsi, Result),
	{reply, ok, State};

handle_call({rar, Imsi}, _From, State) ->
	epdg_diameter_swm:rx_reauth_request(Imsi),
	{reply, ok, State};

handle_call({sta, Imsi, DiaRC}, _From, State) ->
	epdg_diameter_swm:rx_session_termination_answer(Imsi, DiaRC),
	{reply, ok, State};

handle_call({asr, Imsi}, _From, State) ->
	epdg_diameter_swm:rx_abort_session_request(Imsi),
	{reply, ok, State};

handle_call(Request, From, S) ->
	error_logger:error_report(["unknown handle_call", {module, ?MODULE}, {request, Request}, {from, From}, {state, S}]),
	{noreply, S}.

stop() ->
	gen_server:call(?MODULE, stop).

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

terminate(Reason, _S) ->
	lager:info("terminating ~p with reason ~p~n", [?MODULE, Reason]).

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------
