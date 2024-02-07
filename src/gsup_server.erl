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
-include_lib("osmo_gsup/include/gsup_protocol.hrl").
-include_lib("gtplib/include/gtp_packet.hrl").

-define(SERVER, ?MODULE).

-define(IPAC_PROTO_EXT_GSUP,	{osmo, 5}).

-record(gsups_state, {
	lsocket, % listening socket
	lport, % local port. only interesting if we bind with port 0
	socket, % current active socket. we only support a single tcp connection
	ccm_options, % ipa ccm options
	ues = sets:new()
	}).

-record(gsups_ue, {
	imsi                   :: binary(),
	pid                    :: pid()
	}).

-export([start_link/3]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).
-export([code_change/3, terminate/2]).
-export([auth_response/2, lu_response/2, tunnel_response/2, purge_ms_response/2, cancel_location_request/1]).

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
	gen_server:start_link({local, ?SERVER}, ?MODULE, [ServerAddr, ServerPort, Options], [{debug, [trace]}]).

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
			lager:info("GSUP server listen socket ~p~n", [LSocket]),
			{ok, #gsups_state{lsocket = LSocket, lport = Port, ccm_options = CcmOptions}};
		{error, econnrefused} ->
			timer:sleep(5000),
			{stop, connrefused};
		{error, Reason} ->
			timer:sleep(5000),
			{stop, Reason}
	end.

% send a given GSUP message and synchronously wait for message type ExpRes or ExpErr
handle_call(Info, _From, State) ->
	error_logger:error_report(["unknown handle_call", {module, ?MODULE}, {info, Info}, {state, State}]),
	{reply, error, not_implemented}.

handle_cast({auth_response, {Imsi, Auth}}, State) ->
	lager:info("auth_response for ~p: ~p~n", [Imsi, Auth]),
	Socket = State#gsups_state.socket,
	case Auth of
		{ok, Mar} ->	SipAuthTuples = Mar#'MAA'.'SIP-Auth-Data-Item',
				% AuthTuples = dia_sip2gsup(SipAuthTuples),
				Resp = #{message_type => send_auth_info_res,
					message_class => 5,
					imsi => list_to_binary(Mar#'MAA'.'User-Name'),
					auth_tuples => lists:map(fun dia_sip2gsup/1, SipAuthTuples)
					};
		{error, _} ->	Resp = #{message_type => send_auth_info_err, imsi => Imsi, message_class => 5, cause => ?GSUP_CAUSE_NET_FAIL}
	end,
	tx_gsup(Socket, Resp),
	{noreply, State};

handle_cast({lu_response, {Imsi, Result}}, State) ->
	lager:info("lu_response for ~p: ~p~n", [Imsi, Result]),
	Socket = State#gsups_state.socket,
	case Result of
		ok ->	Resp = #{message_type => location_upd_res,
					 imsi => Imsi,
					 message_class => 5
					 };
		{error, _} ->	Resp = #{message_type => location_upd_err,
					 imsi => Imsi,
					 message_class => 5,
					 cause => ?GSUP_CAUSE_NET_FAIL
					 }
	end,
	tx_gsup(Socket, Resp),
	{noreply, State};

handle_cast({tunnel_response, {Imsi, Result}}, State) ->
	lager:info("tunnel_response for ~p: ~p~n", [Imsi, Result]),
	Socket = State#gsups_state.socket,
	case Result of
		{ok, #gtp{version = v2, type = create_session_response}} ->
			{ok, CreateSessResp} = Result,
			IEs = CreateSessResp#gtp.ie,
			%%#{{v2_bearer_context,0} := BearerMap} = IEs,
			#{{v2_pdn_address_allocation,0} := Paa} = IEs,
			PdpAddress = #{pdp_type_org => 1, pdp_type_nr => 16#21, address => #{ ipv4 => Paa#v2_pdn_address_allocation.address}},
			PdpInfo = #{pdp_context_id => 0,
				pdp_address => PdpAddress,
				access_point_name => "foobar.apn",
				quality_of_service => <<0, 0, 0>>,
				pdp_charging => 0},
			Resp = #{message_type => epdg_tunnel_result,
				imsi => Imsi,
				message_class => 5,
				pdp_info_complete => true,
				pdp_info_list => [PdpInfo]
				};
		{error, _} ->
			Resp = #{message_type => epdg_tunnel_error,
				imsi => Imsi,
				message_class => 5,
				cause => ?GSUP_CAUSE_NET_FAIL
				}
	end,
	tx_gsup(Socket, Resp),
	{noreply, State};

handle_cast({purge_ms_response, {Imsi, Result}}, State0) ->
	lager:info("purge_ms_response for ~p: ~p~n", [Imsi, Result]),
	Socket = State0#gsups_state.socket,
	case Result of
		ok ->
			Resp = #{message_type => purge_ms_res,
				imsi => Imsi,
				freeze_p_tmsi => true
				};
		{error, GsupCause} ->
			Resp = #{message_type => purge_ms_err,
				imsi => Imsi,
				cause => GsupCause
				}
	end,
	tx_gsup(Socket, Resp),
	State1 = delete_gsups_ue_by_imsi(Imsi, State0),
	{noreply, State1};

% Our GSUP CEAI implementation for "IKEv2 Information Delete Request"
handle_cast({cancel_location_request, Imsi}, State) ->
	lager:info("cancel_location_request for ~p~n", [Imsi]),
	Socket = State#gsups_state.socket,
	Resp = #{message_type => location_cancellation_req,
		 imsi => Imsi
		},
	tx_gsup(Socket, Resp),
	{noreply, State};

handle_cast(Info, S) ->
	error_logger:error_report(["unknown handle_cast", {module, ?MODULE}, {info, Info}, {state, S}]),
	{noreply, S}.

% When the IPA connection is closed.
handle_info({ipa_closed, _}, S) ->
	lager:error("GSUP connection has been closed"),
	{noreply, S};

% FIXME: handle multiple concurrent connection well
% When a new IPA connection arrives
handle_info({ipa_tcp_accept, Socket}, S) ->
	lager:notice("GSUP connection has been established"),
	ipa_proto:register_socket(Socket),
	ipa_proto:set_ccm_options(Socket, S#gsups_state.ccm_options),
	true = ipa_proto:register_stream(Socket, ?IPAC_PROTO_EXT_GSUP, {process_id, self()}),
	ipa_proto:unblock(Socket),
	{noreply, S#gsups_state{socket=Socket}};

% send auth info / requesting authentication tuples
handle_info({ipa, Socket, ?IPAC_PROTO_EXT_GSUP, _GsupMsgRx = #{message_type := send_auth_info_req, imsi := Imsi}}, State0) ->
	{UE, State1} = find_or_new_gsups_ue(Imsi, State0),
	case epdg_ue_fsm:auth_request(UE#gsups_ue.pid) of
	ok -> State2 = State1;
	{error, Err} ->
		lager:error("Auth Req for Imsi ~p failed: ~p~n", [Imsi, Err]),
		Resp = #{message_type => send_auth_info_err,
			 imsi => Imsi,
			 message_class => 5,
			 cause => ?GSUP_CAUSE_NET_FAIL
		},
		tx_gsup(Socket, Resp),
		epdg_ue_fsm:stop(UE#gsups_ue.pid),
		State2 = delete_gsups_ue(UE, State1)
	end,
	{noreply, State2};

% location update request / when a UE wants to connect to a specific APN. This will trigger a AAA->HLR Request Server Assignment Request
% FIXME: add APN instead of hardcoded internet
handle_info({ipa, Socket, ?IPAC_PROTO_EXT_GSUP, _GsupMsgRx = #{message_type := location_upd_req, imsi := Imsi}}, State) ->
	UE = find_gsups_ue_by_imsi(Imsi, State),
	case UE of
	#gsups_ue{imsi = Imsi} ->
		case epdg_ue_fsm:lu_request(UE#gsups_ue.pid) of
		ok -> ok;
		{error, _} ->
			Resp = #{message_type => location_upd_err,
				 imsi => Imsi,
				 message_class => 5,
				 cause => ?GSUP_CAUSE_NET_FAIL
			},
			tx_gsup(Socket, Resp)
		end;
	undefined ->
		Resp = #{message_type => location_upd_err,
			 imsi => Imsi,
			 message_class => 5,
			 cause => ?GSUP_CAUSE_IMSI_UNKNOWN
		},
		tx_gsup(Socket, Resp)
	end,
	{noreply, State};

% epdg tunnel request / trigger the establishment to the PGW and prepares everything for the user traffic to flow
% When sending a epdg_tunnel_response everything must be ready for the UE traffic
handle_info({ipa, Socket, ?IPAC_PROTO_EXT_GSUP, GsupMsgRx = #{message_type := epdg_tunnel_request, imsi := Imsi}}, State) ->
	lager:info("GSUP: Rx ~p~n", [GsupMsgRx]),
	UE = find_gsups_ue_by_imsi(Imsi, State),
	case UE of
	#gsups_ue{imsi = Imsi} ->
		case epdg_ue_fsm:tunnel_request(UE#gsups_ue.pid) of
		ok -> ok;
		{error, _} ->
			Resp = #{message_type => epdg_tunnel_error,
				imsi => Imsi,
				message_class => 5,
				cause => ?GSUP_CAUSE_NET_FAIL
			},
			tx_gsup(Socket, Resp)
		end;
	undefined ->
		Resp = #{message_type => epdg_tunnel_error,
				imsi => Imsi,
				message_class => 5,
				cause => ?GSUP_CAUSE_IMSI_UNKNOWN
		},
		tx_gsup(Socket, Resp)
	end,
	{noreply, State};

% Purge MS / trigger the delete of session to the PGW
handle_info({ipa, Socket, ?IPAC_PROTO_EXT_GSUP, GsupMsgRx = #{message_type := purge_ms_req, imsi := Imsi}}, State) ->
	lager:info("GSUP: Rx ~p~n", [GsupMsgRx]),
	UE = find_gsups_ue_by_imsi(Imsi, State),
	case UE of
	#gsups_ue{imsi = Imsi} ->
		case epdg_ue_fsm:purge_ms_request(UE#gsups_ue.pid) of
		ok ->	ok;
		_  ->	Resp = #{message_type => purge_ms_err,
				imsi => Imsi,
				message_class => 5,
				cause => ?GSUP_CAUSE_NET_FAIL
			},
			tx_gsup(Socket, Resp)
		end;
	undefined ->
		Resp = #{message_type => purge_ms_err,
			 imsi => Imsi,
			 message_class => 5,
			 cause => ?GSUP_CAUSE_IMSI_UNKNOWN
		},
		tx_gsup(Socket, Resp)
	end,
	{noreply, State};

% Our GSUP CEAI implementation for "IKEv2 Information Delete Response".
handle_info({ipa, Socket, ?IPAC_PROTO_EXT_GSUP, GsupMsgRx = #{message_type := location_cancellation_res, imsi := Imsi}}, State0) ->
	lager:info("GSUP: Rx ~p~n", [GsupMsgRx]),
	UE = find_gsups_ue_by_imsi(Imsi, State0),
	case UE of
	#gsups_ue{imsi = Imsi} -> State1 = delete_gsups_ue(UE, State0);
	undefined -> State1 = State0
	end,
	{noreply, State1};

handle_info(Info, S) ->
	error_logger:error_report(["unknown handle_info", {module, ?MODULE}, {info, Info}, {state, S}]),
	{noreply, S}.

terminate(Reason, _S) ->
	lager:info("terminating ~p with reason ~p~n", [?MODULE, Reason]).

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

auth_response(Imsi, Auth) ->
	lager:info("auth_response(~p): ~p~n", [Imsi, Auth]),
	gen_server:cast(?SERVER, {auth_response, {Imsi, Auth}}).

lu_response(Imsi, Result) ->
	lager:info("lu_response(~p): ~p~n", [Imsi, Result]),
	gen_server:cast(?SERVER, {lu_response, {Imsi, Result}}).

tunnel_response(Imsi, Result) ->
	lager:info("tunnel_response(~p): ~p~n", [Imsi, Result]),
	gen_server:cast(?SERVER, {tunnel_response, {Imsi, Result}}).

purge_ms_response(Imsi, Result) ->
	lager:info("purge_ms_response(~p): ~p~n", [Imsi, Result]),
	gen_server:cast(?SERVER, {purge_ms_response, {Imsi, Result}}).

% Our GSUP CEAI implementation for "IKEv2 Information Delete Request"
cancel_location_request(Imsi) ->
	lager:info("cancel_location_request(~p): ~p~n", [Imsi]),
	gen_server:cast(?SERVER, {cancel_location_request, Imsi}).

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

tx_gsup(Socket, Msg) ->
	lager:info("GSUP: Tx ~p~n", [Msg]),
	ipa_proto:send(Socket, ?IPAC_PROTO_EXT_GSUP, Msg).


new_gsups_ue(Imsi, State) ->
	{ok, Pid} = epdg_ue_fsm:start_link(Imsi),
	UE = #gsups_ue{imsi = Imsi, pid = Pid},
	NewSt = State#gsups_state{ues = sets:add_element(UE, State#gsups_state.ues)},
	{UE, NewSt}.

% returns gsups_ue if found, undefined it not
find_gsups_ue_by_imsi(Imsi, State) ->
	{Imsi, Res} = sets:fold(
			fun(SessIt = #gsups_ue{imsi = LookupImsi}, {LookupImsi, _AccIn}) -> {LookupImsi, SessIt};
			   (_, AccIn) -> AccIn
			end,
			{Imsi, undefined},
			State#gsups_state.ues),
	Res.

find_or_new_gsups_ue(Imsi, State) ->
	UE = find_gsups_ue_by_imsi(Imsi, State),
	case UE of
	    #gsups_ue{imsi = Imsi} ->
		{UE, State};
	    undefined ->
		new_gsups_ue(Imsi, State)
	end.

delete_gsups_ue(UE, State) ->
	SetRemoved = sets:del_element(UE, State#gsups_state.ues),
	lager:debug("Removed UE ~p from ~p~n", [UE, SetRemoved]),
	State#gsups_state{ues = SetRemoved}.

delete_gsups_ue_by_imsi(Imsi, State) ->
	case find_gsups_ue_by_imsi(Imsi, State) of
	undefined -> State;
	UE-> delete_gsups_ue(UE, State)
	end.