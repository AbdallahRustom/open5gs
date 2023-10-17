% simple, blocking/synchronous GSUP client

% (C) 2019 by Harald Welte <laforge@gnumonks.org>
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
% along with this program.  If not, see <http://www.gnu.org/licenses/>.
%
% Additional Permission under GNU AGPL version 3 section 7:
%
% If you modify this Program, or any covered work, by linking or
% combining it with runtime libraries of Erlang/OTP as released by
% Ericsson on http://www.erlang.org (or a modified version of these
% libraries), containing parts covered by the terms of the Erlang Public
% License (http://www.erlang.org/EPLICENSE), the licensors of this
% Program grant you additional permission to convey the resulting work
% without the need to license the runtime libraries of Erlang/OTP under
% the GNU Affero General Public License. Corresponding Source for a
% non-source form of such a combination shall include the source code
% for the parts of the runtime libraries of Erlang/OTP used as well as
% that of the covered work.

-module(gsup_server).

-behaviour(gen_server).

-include_lib("diameter_3gpp_ts29_273_swx.hrl").
-include_lib("osmo_ss7/include/ipa.hrl").

-define(IPAC_PROTO_EXT_GSUP,	{osmo, 5}).

-record(gsups_state, {
	lsocket, % listening socket
	lport, % local port. only interesting if we bind with port 0
	socket, % current active socket. we only support a single tcp connection
	ccm_options % ipa ccm options
	}).

-export([start_link/3]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).
-export([code_change/3, terminate/2]).

% TODO: -spec dia_sip2gsup('SIP-Auth-Data-Item'()) -> #'GSUPAuthTuple'{}.
dia_sip2gsup(#'SIP-Auth-Data-Item'{'SIP-Authenticate' = [Authenticate], 'SIP-Authorization' = [Authorization],
				   'Confidentiality-Key' = [CKey], 'Integrity-Key' = [IKey]}) ->
	lager:info("dia_sip2gsup: auth ~p authz ~p ~n", [Authenticate, Authorization]),
	lager:info("  rand ~p autn ~p ~n", [lists:sublist(Authenticate, 1, 16), lists:sublist(Authenticate, 17, 16)]),
	#{rand => list_to_binary(lists:sublist(Authenticate, 1, 16)),
	  autn=> list_to_binary(lists:sublist(Authenticate, 17, 16)),
	  res=> list_to_binary(Authorization),
	  ik=> list_to_binary(IKey),
	  ck=> list_to_binary(CKey)}.

%% ------------------------------------------------------------------
%% our exported API
%% ------------------------------------------------------------------

start_link(ServerAddr, ServerPort, Options) ->
	gen_server:start_link(?MODULE, [ServerAddr, ServerPort, Options], [{debug, [trace]}]).

%% ------------------------------------------------------------------
%% gen_server Function Definitions
%% ------------------------------------------------------------------

init([Address, Port, Options]) ->
	ipa_proto:init(),
	% register the GSUP codec with the IPA core; ignore result as we mgiht be doing this multiple times
	ipa_proto:register_codec(?IPAC_PROTO_EXT_GSUP, fun gsup_protocol:encode/1, fun gsup_protocol:decode/1),
	lager:info("GSUP Server on IP ~s port ~p~n", [Address, Port]),
	CcmOptions = #ipa_ccm_options{
		serial_number="EPDG-00-00-00-00-00-00",
		unit_id="0/0/0",
		mac_address="00:00:00:00:00:00",
		location="00:00:00:00:00:00",
		unit_type="00:00:00:00:00:00",
		equipment_version="00:00:00:00:00:00",
		sw_version="00:00:00:00:00:00",
		unit_name="EPDG-00-00-00-00-00-00"
	},
	case ipa_proto:start_listen(Port, 1, Options) of
		{ok, LSocket, Port} ->
			lager:info("connected!~n", []),
			{ok, #gsups_state{lsocket = LSocket, lport = Port, ccm_options = CcmOptions}};
		{error, econnrefused} ->
			timer:sleep(5000),
			{stop, connrefused};
		{error, Reason} ->
			timer:sleep(5000),
			{stop, Reason}
	end.

% send a given GSUP message and synchronously wait for message type ExpRes or ExpErr
handle_call({transceive_gsup, GsupMsgTx, ExpRes, ExpErr}, _From, State) ->
	Socket = State#gsups_state.socket,
	{ok, Imsi} = maps:find(imsi, GsupMsgTx),
	ipa_proto:send(Socket, ?IPAC_PROTO_EXT_GSUP, GsupMsgTx),
	% selective receive for only those GSUP responses we expect
	receive
		{ipa, Socket, ?IPAC_PROTO_EXT_GSUP, GsupMsgRx = #{message_type := ExpRes, imsi := Imsi}} ->
			{reply, GsupMsgRx, State};

		{ipa, Socket, ?IPAC_PROTO_EXT_GSUP, GsupMsgRx = #{message_type := ExpErr, imsi := Imsi}} ->
			{reply, GsupMsgRx, State}
	after 5000 ->
		{reply, timeout, State}
	end.

handle_cast(Info, S) ->
	error_logger:error_report(["unknown handle_cast", {module, ?MODULE}, {info, Info}, {state, S}]),
	{noreply, S}.

% When the IPA connection is closed.
handle_info({ipa_closed, _}, S) ->
	lager:error("GSUP connection has been closed, supervisor should reconnect us"),
	{noreply, S};

% FIXME: handle multiple concurrent connection well
% When a new IPA connection arrives
handle_info({ipa_tcp_accept, Socket}, S) ->
	lager:notice("GSUP connection has been established"),
	ipa_proto:register_socket(Socket),
	ipa_proto:set_ccm_options(Socket, S#gsups_state.ccm_options),
	true = ipa_proto:register_stream(Socket, ?IPAC_PROTO_EXT_GSUP, {process_id, self()}),
	ipa_proto:unblock(Socket),
	lager:info("connected!~n", []),
	{noreply, S#gsups_state{socket=Socket}};

% send auth info / requesting authentication tuples
handle_info({ipa, Socket, ?IPAC_PROTO_EXT_GSUP, GsupMsgRx = #{message_type := send_auth_info_req, imsi := Imsi}}, S) ->
	Auth = auth_handler:auth_request(Imsi),
	case Auth of
		{ok, Mar} ->	SipAuthTuples = Mar#'MAA'.'SIP-Auth-Data-Item',
				% AuthTuples = dia_sip2gsup(SipAuthTuples),
				Resp = #{message_type => send_auth_info_res,
					 message_class => 5,
					 imsi => list_to_binary(Mar#'MAA'.'User-Name'),
					 auth_tuples => lists:map(fun dia_sip2gsup/1, SipAuthTuples)
					};
		{error, _} ->	Resp = #{message_type => send_auth_info_err, imsi => Imsi, message_class => 5, cause => 16#11}
	end,
	lager:info("auth tuples: ~p ~n", [Resp]),
	ipa_proto:send(Socket, ?IPAC_PROTO_EXT_GSUP, Resp),
	{noreply, S};

% location update request / when a UE wants to connect to a specific APN. This will trigger a AAA->HLR Request Server Assignment Request
% FIXME: add APN instead of hardcoded internet
handle_info({ipa, Socket, ?IPAC_PROTO_EXT_GSUP, GsupMsgRx = #{message_type := location_upd_req, imsi := Imsi}}, S) ->
	% FIXME: use enum for Server-Assignment-Type => REGISTERING
	Result = epdg_diameter_swx:server_assignment_request(Imsi, 1, "internet"),
	case Result of
		{ok, Sar} ->	Resp = #{message_type => location_upd_res,
					 imsi => Imsi,
					 message_class => 5
					 };
		{error, _} ->	Resp = #{message_type => location_upd_err,
					 imsi => Imsi,
					 message_class => 5,
					 cause => 16#11 % FIXME: Use proper defines as cause code and use Network failure
					 }
	end,
	ipa_proto:send(Socket, ?IPAC_PROTO_EXT_GSUP, Resp),
	{noreply, S};

% epdg tunnel request / trigger the establishment to the PGW and prepares everything for the user traffic to flow
% When sending a epdg_tunnel_response everything must be ready for the UE traffic
handle_info({ipa, Socket, ?IPAC_PROTO_EXT_GSUP, GsupMsgRx = #{message_type := epdg_tunnel_request, imsi := Imsi}}, S) ->
	lager:info("GSUP: Rx ~p~n", [GsupMsgRx]),
	Result = epdg_gtpc_s2b:create_session_req(Imsi),
	case Result of
		{ok, _} ->
			Resp = #{message_type => epdg_tunnel_result,
				 imsi => Imsi,
				 message_class => 5
				};
		{error, _} ->
			Resp = #{message_type => epdg_tunnel_error,
				 imsi => Imsi,
				 message_class => 5,
				 cause => 16#11 % FIXME: Use proper defines as cause code and use Network failure
				}
	end,
	lager:info("GSUP: Tx ~p~n", [Resp]),
	ipa_proto:send(Socket, ?IPAC_PROTO_EXT_GSUP, Resp),
	{noreply, S};

handle_info(Info, S) ->
	error_logger:error_report(["unknown handle_info", {module, ?MODULE}, {info, Info}, {state, S}]),
	{noreply, S}.

terminate(Reason, _S) ->
	lager:info("terminating ~p with reason ~p~n", [?MODULE, Reason]).

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.
