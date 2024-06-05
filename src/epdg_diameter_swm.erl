% ePDG implementation of SWm Diameter interface, TS 29.273 section 7
% This interface is so far implemented through internal erlang messages against
% the internal AAA Server.

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


-module(epdg_diameter_swm).
-behaviour(gen_server).

-include_lib("diameter_3gpp_ts29_273_swx.hrl").
-include("conv.hrl").

-record(swm_state, {
}).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).
-export([code_change/3, terminate/2]).

-export([tx_der_auth_request/4,
	 tx_der_auth_compl_request/2,
	 tx_reauth_answer/2,
	 tx_auth_req/1,
	 tx_session_termination_request/1,
	 tx_abort_session_answer/1]).
-export([rx_dea_auth_response/2,
	 rx_dea_auth_compl_response/2,
	 rx_reauth_request/1,
	 rx_auth_answer/2,
	 rx_session_termination_answer/2,
	 rx_abort_session_request/1]).

-define(SERVER, ?MODULE).

% The ets table contains only IMSIs

start_link() ->
	gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
	{ok, #swm_state{}}.


%% Swm Diameter message Diameter-EAP-Request, 3GPP TS 29.273 Table 7.1.2.1.1
tx_der_auth_request(Imsi, PdpTypeNr, Apn, EAP) ->
	% In Diameter we use Imsi as strings, as done by diameter module.
	ImsiStr = binary_to_list(Imsi),
	% PdpTypeNr: SWm Diameter AVP "UE-Local-IP-Address"
	% Apn: SWm Diameter AVP "Service-Selection"
	% EAP: SWm Diameter AVP EAP-Payload
	ok = gen_server:cast(?SERVER, {tx_dia, {der_auth_req, ImsiStr, PdpTypeNr, Apn, EAP}}).

tx_reauth_answer(Imsi, DiaRC) ->
	% In Diameter we use Imsi as strings, as done by diameter module.
	ImsiStr = binary_to_list(Imsi),
	ok = gen_server:cast(?SERVER, {tx_dia, {raa, ImsiStr, DiaRC}}).

% Rx "GSUP CEAI LU Req" is our way of saying Rx "Swm Diameter-EAP REQ (DER) with EAP AVP containing successuful auth":
tx_der_auth_compl_request(Imsi, Apn) ->
	% In Diameter we use Imsi as strings, as done by diameter module.
	ImsiStr = binary_to_list(Imsi),
	ok = gen_server:cast(?SERVER, {tx_dia, {der_auth_compl_req, ImsiStr, Apn}}).

% 3GPP TS 29.273 7.1.2.2
tx_auth_req(Imsi) ->
	% In Diameter we use Imsi as strings, as done by diameter module.
	ImsiStr = binary_to_list(Imsi),
	ok = gen_server:cast(?SERVER, {tx_dia, {aar, ImsiStr}}).

% 3GPP TS 29.273 7.1.2.3
tx_session_termination_request(Imsi) ->
	% In Diameter we use Imsi as strings, as done by diameter module.
	ImsiStr = binary_to_list(Imsi),
	ok = gen_server:cast(?SERVER, {tx_dia, {str, ImsiStr}}).

% 3GPP TS 29.273 7.1.2.4
tx_abort_session_answer(Imsi) ->
	% In Diameter we use Imsi as strings, as done by diameter module.
	ImsiStr = binary_to_list(Imsi),
	ok = gen_server:cast(?SERVER, {tx_dia, {asa, ImsiStr}}).

%% Emulation from the wire (DIAMETER SWm), called from internal AAA Server:
rx_reauth_request(Imsi) ->
	ok = gen_server:cast(?SERVER, {rx_dia, {rar, Imsi}}).

%% Emulation from the wire (DIAMETER SWm), called from internal AAA Server:
rx_auth_answer(Imsi, Result) ->
	ok = gen_server:cast(?SERVER, {rx_dia, {aaa, Imsi, Result}}).

%% Emulation from the wire (DIAMETER SWm), called from internal AAA Server:
rx_dea_auth_response(Imsi, Result) ->
	ok = gen_server:cast(?SERVER, {rx_dia, {dea_auth_resp, Imsi, Result}}).

%Rx Swm Diameter-EAP Answer (DEA) containing APN-Configuration, triggered by
%earlier Tx DER EAP AVP containing successuful auth":
rx_dea_auth_compl_response(Imsi, Result) ->
	ok = gen_server:cast(?SERVER, {rx_dia, {dea_auth_compl_resp, Imsi, Result}}).

% Rx SWm Diameter STA:
rx_session_termination_answer(Imsi, Result) ->
	ok = gen_server:cast(?SERVER, {rx_dia, {sta, Imsi, Result}}).

% Rx SWm Diameter ASR:
rx_abort_session_request(Imsi) ->
	ok = gen_server:cast(?SERVER, {rx_dia, {asr, Imsi}}).


%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

handle_call(Request, From, State) ->
	error_logger:error_report(["unknown handle_call", {module, ?MODULE}, {request, Request}, {from, From}, {state, State}]),
	{reply, ok, State}.

handle_cast({tx_dia, {der_auth_req, Imsi, PdpTypeNr, Apn, EAP}}, State) ->
	% we yet don't implement the Diameter SWm interface on the wire, we process the call internally:
	aaa_diameter_swm:rx_der_auth_request(Imsi, PdpTypeNr, Apn, EAP),
	{noreply, State};

handle_cast({tx_dia, {raa, Imsi, DiaRC}}, State) ->
	% we yet don't implement the Diameter SWm interface on the wire, we process the call internally:
	aaa_diameter_swm:rx_reauth_answer(Imsi, DiaRC#epdg_dia_rc.result_code),
	{noreply, State};

handle_cast({tx_dia, {der_auth_compl_req, Imsi, Apn}}, State) ->
	% we yet don't implement the Diameter SWm interface on the wire, we process the call internally:
	aaa_diameter_swm:rx_der_auth_compl_request(Imsi, Apn),
	{noreply, State};

% 3GPP TS 29.273 7.2.2.1.3 Diameter-AA-Request (AAR) Command
handle_cast({tx_dia, {aar, Imsi}}, State) ->
	% we yet don't implement the Diameter SWm interface on the wire, we process the call internally:
	aaa_diameter_swm:rx_auth_request(Imsi),
	{noreply, State};

handle_cast({tx_dia, {str, Imsi}}, State) ->
	% we yet don't implement the Diameter SWm interface on the wire, we process the call internally:
	aaa_diameter_swm:rx_session_termination_request(Imsi),
	{noreply, State};

handle_cast({tx_dia, {asa, Imsi}}, State) ->
	% we yet don't implement the Diameter SWm interface on the wire, we process the call internally:
	aaa_diameter_swm:rx_abort_session_answer(Imsi),
	{noreply, State};

handle_cast({rx_dia, {dea_auth_resp, ImsiStr, Result}}, State) ->
	Imsi = list_to_binary(ImsiStr),
	case epdg_ue_fsm:get_pid_by_imsi(Imsi) of
	Pid when is_pid(Pid) ->
		epdg_ue_fsm:received_swm_dea_auth_response(Pid, Result);
	undefined ->
		error_logger:error_report(["unknown swm_session", {module, ?MODULE}, {imsi, Imsi}, {state, State}])
	end,
	{noreply, State};

handle_cast({rx_dia, {dea_auth_compl_resp, ImsiStr, Result}}, State) ->
	Imsi = list_to_binary(ImsiStr),
	case epdg_ue_fsm:get_pid_by_imsi(Imsi) of
	Pid when is_pid(Pid) ->
		epdg_ue_fsm:received_swm_dea_auth_compl_response(Pid, Result);
	undefined ->
		error_logger:error_report(["unknown swm_session", {module, ?MODULE}, {imsi, Imsi}, {state, State}])
	end,
	{noreply, State};

handle_cast({rx_dia, {rar, ImsiStr}}, State) ->
	Imsi = list_to_binary(ImsiStr),
	case epdg_ue_fsm:get_pid_by_imsi(Imsi) of
	Pid when is_pid(Pid) ->
		epdg_ue_fsm:received_swm_reauth_request(Pid);
	undefined ->
		lager:notice("SWm Rx RAR: unknown swm-session ~p", [Imsi]),
		DiaResultCode = 5002, %% UNKNOWN_SESSION_ID
		aaa_diameter_swm:rx_reauth_answer(ImsiStr, DiaResultCode)
	end,
	{noreply, State};

handle_cast({rx_dia, {aaa, ImsiStr, Result}}, State) ->
	Imsi = list_to_binary(ImsiStr),
	case epdg_ue_fsm:get_pid_by_imsi(Imsi) of
	Pid when is_pid(Pid) ->
		epdg_ue_fsm:received_swm_auth_answer(Pid, Result);
	undefined ->
		lager:notice("SWm Rx RAR: unknown swm-session ~p", [Imsi])
	end,
	{noreply, State};

handle_cast({rx_dia, {sta, ImsiStr, Result}}, State) ->
	Imsi = list_to_binary(ImsiStr),
	case epdg_ue_fsm:get_pid_by_imsi(Imsi) of
	Pid when is_pid(Pid) ->
		epdg_ue_fsm:received_swm_session_termination_answer(Pid, Result);
	undefined ->
		error_logger:error_report(["unknown swm_session", {module, ?MODULE}, {imsi, Imsi}, {state, State}])
	end,
	{noreply, State};

handle_cast({rx_dia, {asr, ImsiStr}}, State) ->
	Imsi = list_to_binary(ImsiStr),
	case epdg_ue_fsm:get_pid_by_imsi(Imsi) of
	Pid when is_pid(Pid) ->
		epdg_ue_fsm:received_swm_abort_session_request(Pid);
	undefined ->
		error_logger:error_report(["unknown swm_session", {module, ?MODULE}, {imsi, Imsi}, {state, State}])
	end,
	{noreply, State};

handle_cast(Info, S) ->
	error_logger:error_report(["unknown handle_cast", {module, ?MODULE}, {info, Info}, {state, S}]),
	{noreply, S}.
handle_info(Info, S) ->
	error_logger:error_report(["unknown handle_info", {module, ?MODULE}, {info, Info}, {state, S}]),
	{noreply, S}.


stop() ->
	gen_server:call(?MODULE, stop).

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

terminate(Reason, _S) ->
	lager:info("terminating ~p with reason ~p~n", [?MODULE, Reason]).
