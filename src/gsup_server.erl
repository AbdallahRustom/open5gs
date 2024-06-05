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

-module(gsup_server).

-behaviour(gen_server).

-include_lib("osmo_ss7/include/ipa.hrl").
-include_lib("osmo_gsup/include/gsup_protocol.hrl").
-include("gtp_utils.hrl").
-include("conv.hrl").

-define(SERVER, ?MODULE).

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
-export([auth_response/2,
	 lu_response/2,
	 tunnel_response/2,
	 purge_ms_response/2,
	 cancel_location_request/1, cancel_location_request/2]).

% TODO: -spec dia_sip2gsup(#epdg_auth_tuple{}) -> map().
epdg_auth_tuple2gsup(#epdg_auth_tuple{rand = Rand, autn = Autn, res = Res, ck = Ck, ik = Ik}) ->
	#{rand => Rand, autn => Autn, res => Res, ik => Ik, ck => Ck}.

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

handle_cast({auth_response, {Imsi, Result}}, State) ->
	lager:info("auth_response for ~p: ~p~n", [Imsi, Result]),
	Socket = State#gsups_state.socket,
	case Result of
		{ok, AuthTuples} ->
				Resp = #{message_type => send_auth_info_res,
					message_class => 5,
					imsi => Imsi,
					auth_tuples => lists:map(fun epdg_auth_tuple2gsup/1, AuthTuples)
					};
		{error, Gsupcause} ->
				Resp = #{message_type => send_auth_info_err,
					 imsi => Imsi,
					 message_class => 5,
					 cause => Gsupcause
					}
	end,
	tx_gsup(Socket, Resp),
	{noreply, State};

handle_cast({lu_response, {Imsi, Result}}, State) ->
	lager:info("lu_response for ~p: ~p~n", [Imsi, Result]),
	Socket = State#gsups_state.socket,
	case Result of
		ok ->
			Resp = #{message_type => location_upd_res,
				 imsi => Imsi,
				 message_class => 5
				 };
		{error, Gsupcause} ->
			Resp = #{message_type => location_upd_err,
				 imsi => Imsi,
				 message_class => 5,
				 cause => Gsupcause
				}
	end,
	tx_gsup(Socket, Resp),
	{noreply, State};

handle_cast({tunnel_response, {Imsi, Result}}, State) ->
	lager:info("tunnel_response for ~p: ~p~n", [Imsi, Result]),
	Socket = State#gsups_state.socket,
	case Result of
		{ok, #{apn := Apn, eua := Eua} = Map} ->
			PdpInfo = #{pdp_context_id => 0,
				    pdp_address => conv:epdg_eua_to_gsup_pdp_address(Eua),
				    access_point_name => Apn,
				    quality_of_service => <<0, 0, 0>>,
				    pdp_charging => 0},
			Resp0 = #{message_type => epdg_tunnel_result,
				  imsi => Imsi,
				  message_class => 5,
				  pdp_info_complete => true,
				  pdp_info_list => [PdpInfo]},
			case maps:find(apco, Map) of
			{ok, APCO} -> Resp = maps:put(pco, APCO, Resp0);
			error -> Resp = Resp0
			end;
		{error, GsupCause} ->
			Resp = #{message_type => epdg_tunnel_error,
				imsi => Imsi,
				message_class => 5,
				cause => GsupCause
				}
	end,
	tx_gsup(Socket, Resp),
	{noreply, State};

handle_cast({purge_ms_response, {Imsi, Result}}, State) ->
	lager:info("purge_ms_response for ~p: ~p~n", [Imsi, Result]),
	Socket = State#gsups_state.socket,
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
	case epdg_ue_fsm:get_pid_by_imsi(Imsi) of
		Pid when is_pid(Pid) -> epdg_ue_fsm:stop(Pid);
		undefined -> ok
	end,
	{noreply, State};

% Our GSUP CEAI implementation for "IKEv2 Information Delete Request"
handle_cast({cancel_location_request, Imsi, CancelType}, State) ->
	lager:info("cancel_location_request for ~p~n", [Imsi]),
	Socket = State#gsups_state.socket,
	Resp0 = #{message_type => location_cancellation_req,
		  imsi => Imsi,
		  cn_domain => ?GSUP_CN_DOMAIN_PS
		},
	case CancelType of
	undefined -> Resp = Resp0;
	_ -> Resp = maps:put(cancellation_type, CancelType, Resp0)
	end,
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

%% Rx IPA/GSUP message:
handle_info({ipa, Socket, ?IPAC_PROTO_EXT_GSUP, GsupMsgRx}, State) ->
	lager:info("GSUP: Rx ~p~n", [GsupMsgRx]),
	misc:spawn_wait_ret(fun() ->
				rx_gsup(Socket, GsupMsgRx, State)
			    end,
			    {noreply, State});

handle_info(Info, S) ->
	error_logger:error_report(["unknown handle_info", {module, ?MODULE}, {info, Info}, {state, S}]),
	{noreply, S}.

terminate(Reason, _S) ->
	lager:info("terminating ~p with reason ~p~n", [?MODULE, Reason]).

code_change(_OldVsn, State, _Extra) ->
	{ok, State}.

auth_response(Imsi, Result) ->
	lager:info("auth_response(~p): ~p~n", [Imsi, Result]),
	gen_server:cast(?SERVER, {auth_response, {Imsi, Result}}).

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
	cancel_location_request(Imsi, undefined).
cancel_location_request(Imsi, CancelType) ->
	lager:info("cancel_location_request(~p, ~p)~n", [Imsi, CancelType]),
	gen_server:cast(?SERVER, {cancel_location_request, Imsi, CancelType}).

%% ------------------------------------------------------------------
%% Internal Function Definitions
%% ------------------------------------------------------------------

%% Put params transparent to ePDG in a container, they are for AAA Server (RFC7296):
parse_eap(GsupMsgRx = #{message_type := send_auth_info_req}) ->
	RandRes = maps:find(rand, GsupMsgRx),
	AutsRes = maps:find(auts, GsupMsgRx),
	case {RandRes, AutsRes} of
	{{ok, <<Rand:16/binary>>}, {ok, <<Auts:14/binary>>}} ->
		% Authorization: SWx Diameter AVP SIP-Authorization for resynchronisation of the Simcard
		EAP = #{authorization => <<Rand:16/binary, Auts:14/binary>>};
	_ ->
		EAP = #{}
	end,
	EAP.

% Rx send auth info / requesting authentication tuples
rx_gsup(Socket, GsupMsgRx = #{message_type := send_auth_info_req, imsi := Imsi}, State) ->
	case maps:find(pdp_info_list, GsupMsgRx) of
	{ok, [PdpInfo]} ->
		#{pdp_context_id := _PDPCtxId,
		  pdp_address := #{address := #{},
				   pdp_type_nr := PdpTypeNr,
				   pdp_type_org := 241},
		  access_point_name := Apn
		} = PdpInfo;
	error -> % Use some sane defaults:
		PdpTypeNr = ?GTP_PDP_ADDR_TYPE_NR_IPv4,
		Apn = "*"
	end,
	EAP = parse_eap(GsupMsgRx),
	case epdg_ue_fsm:get_pid_by_imsi(Imsi) of
		undefined -> {ok, Pid} = epdg_ue_fsm:start(Imsi);
		Pid -> Pid
	end,
	case epdg_ue_fsm:auth_request(Pid, {PdpTypeNr, Apn, EAP}) of
	ok -> ok;
	{error, Err} ->
		lager:error("Auth Req for Imsi ~p failed: ~p~n", [Imsi, Err]),
		Resp = #{message_type => send_auth_info_err,
			 imsi => Imsi,
			 message_class => 5,
			 cause => ?GSUP_CAUSE_NET_FAIL
		},
		tx_gsup(Socket, Resp),
		epdg_ue_fsm:stop(Pid)
	end,
	{noreply, State};

% location update request / when a UE wants to connect to a specific APN. This will trigger a AAA->HLR Request Server Assignment Request
rx_gsup(Socket, _GsupMsgRx = #{message_type := location_upd_req, imsi := Imsi}, State) ->
	case epdg_ue_fsm:get_pid_by_imsi(Imsi) of
	Pid when is_pid(Pid) ->
		case epdg_ue_fsm:lu_request(Pid) of
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
rx_gsup(Socket, _GsupMsgRx = #{message_type := epdg_tunnel_request, imsi := Imsi, pco := PCO}, State) ->
	case epdg_ue_fsm:get_pid_by_imsi(Imsi) of
	Pid when is_pid(Pid) ->
		case epdg_ue_fsm:tunnel_request(Pid, PCO) of
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
rx_gsup(Socket, _GsupMsgRx = #{message_type := purge_ms_req, imsi := Imsi}, State) ->
	case epdg_ue_fsm:get_pid_by_imsi(Imsi) of
	Pid when is_pid(Pid) ->
		case epdg_ue_fsm:purge_ms_request(Pid) of
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
rx_gsup(_Socket, _GsupMsgRx = #{message_type := location_cancellation_res, imsi := Imsi}, State) ->
	case epdg_ue_fsm:get_pid_by_imsi(Imsi) of
		Pid when is_pid(Pid) ->
			epdg_ue_fsm:cancel_location_result(Pid);
		undefined -> State
	end,
	{noreply, State};

rx_gsup(_Socket, GsupMsgRx, State) ->
	lager:error("GSUP: Rx unimplemented msg: ~p~n", [GsupMsgRx]),
	{noreply, State}.

tx_gsup(Socket, Msg) ->
	lager:info("GSUP: Tx ~p~n", [Msg]),
	ipa_proto:send(Socket, ?IPAC_PROTO_EXT_GSUP, Msg).
