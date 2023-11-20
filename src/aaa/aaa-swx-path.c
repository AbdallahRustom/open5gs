/*
 * Copyright (C) 2019 by Sukchan Lee <acetcom@gmail.com>
 *
 * This file is part of Open5GS.
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU Affero General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <https://www.gnu.org/licenses/>.
 */

#include "ogs-diameter-swx.h"

#include "aaa-context.h"
#include "aaa-fd-path.h"
#include "aaa-s6b-path.h"
#include "aaa-swx-path.h"

static struct session_handler *aaa_swx_reg = NULL;

static OGS_POOL(sess_state_pool, struct sess_state);
static ogs_thread_mutex_t sess_state_mutex;

static struct disp_hdl *hdl_swx_fb = NULL;

static void aaa_swx_send_mar(struct sess_state *sess_data);
static void aaa_swx_maa_cb(void *data, struct msg **msg);

static void aaa_swx_saa_cb(void *data, struct msg **msg);

static void state_cleanup(struct sess_state *sess_data, os0_t sid, void *opaque)
{
    if (sess_data->hss_host)
        ogs_free(sess_data->hss_host);

    if (sess_data->smf_host)
        ogs_free(sess_data->smf_host);

    if (sess_data->user_name)
        ogs_free(sess_data->user_name);

    ogs_thread_mutex_lock(&sess_state_mutex);
    ogs_pool_free(&sess_state_pool, sess_data);
    ogs_thread_mutex_unlock(&sess_state_mutex);
}

static int aaa_swx_fb_cb(struct msg **msg, struct avp *avp,
        struct session *sess, void *opaque, enum disp_action *act)
{
    /* This CB should never be called */
    ogs_warn("Unexpected message received!");

    return ENOTSUP;
}

void aaa_swx_send(aaa_sess_t *sess, bool handover_ind,
        int (*gtp_send)(aaa_sess_t *sess, bool handover_ind))
{
    struct sess_state *sess_data = NULL;

    ogs_assert(sess);
    ogs_assert(gtp_send);

    /* Create the random value to store with the session */
    sess_data = ogs_calloc(1, sizeof (*sess_data));
    ogs_assert(sess_data);

    sess_data->sess = sess;
    sess_data->gtp_send = gtp_send;
    sess_data->handover_ind = handover_ind;

    aaa_swx_send_mar(sess_data);
}

static void aaa_swx_send_mar(struct sess_state *sess_data)
{
    int ret;

    struct msg *req = NULL;

    struct msg_hdr *msg_header = NULL;

    struct session *session = NULL;
    struct sess_state *svg;

    struct avp *avp = NULL, *avpch = NULL;
    union avp_value val;

    aaa_ue_t *aaa_ue = NULL;
    aaa_sess_t *sess = NULL;

    uint8_t resync[OGS_AUTS_LEN + OGS_RAND_LEN];

    ogs_assert(sess_data);
    sess = sess_data->sess;
    ogs_assert(sess);
    aaa_ue = sess->aaa_ue;
    ogs_assert(aaa_ue);

    ogs_debug("Multimedia-Auth-Request");

    /* Create the request */
    ret = fd_msg_new(ogs_diam_cx_cmd_mar, MSGFL_ALLOC_ETEID, &req);
    ogs_assert(ret == 0);

    ret = fd_msg_hdr(req, &msg_header);
    ogs_assert(ret == 0);
    msg_header->msg_appl = OGS_DIAM_SWX_APPLICATION_ID;

    #define OGS_DIAM_SWX_APP_SID_OPT  "app_swx"
    ret = fd_msg_new_session(req, (os0_t)OGS_DIAM_SWX_APP_SID_OPT,
            CONSTSTRLEN(OGS_DIAM_SWX_APP_SID_OPT));
    ogs_assert(ret == 0);
    ret = fd_msg_sess_get(fd_g_config->cnf_dict, req, &session, NULL);
    ogs_assert(ret == 0);

    /* Set Vendor-Specific-Application-Id AVP */
    ret = ogs_diam_message_vendor_specific_appid_set(
            req, OGS_DIAM_SWX_APPLICATION_ID);
    ogs_assert(ret == 0);

    /* Set the Auth-Session-State AVP */
    ret = fd_msg_avp_new(ogs_diam_auth_session_state, 0, &avp);
    ogs_assert(ret == 0);
    val.i32 = OGS_DIAM_AUTH_SESSION_NO_STATE_MAINTAINED;
    ret = fd_msg_avp_setvalue(avp, &val);
    ogs_assert(ret == 0);
    ret = fd_msg_avp_add(req, MSG_BRW_LAST_CHILD, avp);
    ogs_assert(ret == 0);

    /* Set Origin-Host & Origin-Realm */
    ret = fd_msg_add_origin(req, 0);
    ogs_assert(ret == 0);

    /* Set the Destination-Host AVP */
    ret = fd_msg_avp_new(ogs_diam_destination_host, 0, &avp);
    ogs_assert(ret == 0);
    val.os.data = sess_data->hss_host;
    val.os.len  = strlen((char *)sess_data->hss_host);
    ret = fd_msg_avp_setvalue(avp, &val);
    ogs_assert(ret == 0);
    ret = fd_msg_avp_add(req, MSG_BRW_LAST_CHILD, avp);
    ogs_assert(ret == 0);

    /* Set the Destination-Realm AVP */
    ret = fd_msg_avp_new(ogs_diam_destination_realm, 0, &avp);
    ogs_assert(ret == 0);
    val.os.data = (unsigned char *)(fd_g_config->cnf_diamrlm);
    val.os.len  = strlen(fd_g_config->cnf_diamrlm);
    ret = fd_msg_avp_setvalue(avp, &val);
    ogs_assert(ret == 0);
    ret = fd_msg_avp_add(req, MSG_BRW_LAST_CHILD, avp);
    ogs_assert(ret == 0);

    /* Set the User-Name AVP */
    if (sess_data->user_name)
        ogs_free(sess_data->user_name);
    sess_data->user_name =
        ogs_msprintf("%s@%s", aaa_ue->imsi, fd_g_config->cnf_diamrlm);
    ogs_assert(sess_data->user_name);

    ret = fd_msg_avp_new(ogs_diam_user_name, 0, &avp);
    ogs_assert(ret == 0);
    val.os.data = (uint8_t *)sess_data->user_name;
    val.os.len = strlen(sess_data->user_name);
    ret = fd_msg_avp_setvalue(avp, &val);
    ogs_assert(ret == 0);
    ret = fd_msg_avp_add(req, MSG_BRW_LAST_CHILD, avp);
    ogs_assert(ret == 0);

    /* Set the RAT-Type AVP */
    ret = fd_msg_avp_new(ogs_diam_rat_type, 0, &avp);
    ogs_assert(ret == 0);
    val.i32 = OGS_DIAM_RAT_TYPE_WLAN;
    ret = fd_msg_avp_setvalue(avp, &val);
    ogs_assert(ret == 0);
    ret = fd_msg_avp_add(req, MSG_BRW_LAST_CHILD, avp);
    ogs_assert(ret == 0);

    /* Set the SIP-Auth-Data-Item AVP */
    ret = fd_msg_avp_new(ogs_diam_cx_sip_auth_data_item, 0, &avp);
    ogs_assert(ret == 0);

    if (sess_data->resync == true) {
        uint8_t ak[OGS_AK_LEN];
        uint8_t sqn[OGS_SQN_LEN];
        uint8_t amf[2] = { 0, 0 };
        uint8_t auts[OGS_AUTS_LEN];

        uint64_t sqn_ms;
        int i;

        ogs_hex_from_string(
                aaa_ue->k_string, aaa_ue->k, sizeof(aaa_ue->k));
        ogs_hex_from_string(
                aaa_ue->opc_string, aaa_ue->opc, sizeof(aaa_ue->opc));

        milenage_f2345(aaa_ue->opc, aaa_ue->k, aaa_ue->rand,
                NULL, NULL, NULL, NULL, ak);

        sqn_ms = 0x11223344;
        ogs_uint64_to_buffer(sqn_ms, 6, sqn);
        milenage_f1(aaa_ue->opc, aaa_ue->k, aaa_ue->rand,
                sqn, amf, NULL, auts + OGS_SQN_LEN);
        for (i = 0; i < OGS_SQN_LEN; i++)
            auts[i] = sqn[i] ^ ak[i];

        memset(resync, 0, sizeof resync);
        memcpy(resync, aaa_ue->rand, OGS_RAND_LEN);
        memcpy(resync+OGS_RAND_LEN, auts, OGS_AUTS_LEN);

        ret = fd_msg_avp_new(ogs_diam_cx_sip_authorization, 0, &avpch);
        ogs_assert(ret == 0);
        val.os.len = OGS_RAND_LEN+OGS_AUTS_LEN;
        val.os.data = resync;
        ret = fd_msg_avp_setvalue(avpch, &val);
        ogs_assert(ret == 0);
        ret = fd_msg_avp_add(avp, MSG_BRW_LAST_CHILD, avpch);
        ogs_assert(ret == 0);
    } else {
        ret = fd_msg_avp_new(ogs_diam_cx_sip_authentication_scheme, 0, &avpch);
        ogs_assert(ret == 0);
        val.os.data = (uint8_t *)OGS_DIAM_SWX_AUTH_SCHEME_EAP_AKA;
        val.os.len = strlen(OGS_DIAM_SWX_AUTH_SCHEME_EAP_AKA);
        ret = fd_msg_avp_setvalue(avpch, &val);
        ogs_assert(ret == 0);
        ret = fd_msg_avp_add(avp, MSG_BRW_LAST_CHILD, avpch);
        ogs_assert(ret == 0);
    }

    ret = fd_msg_avp_add(req, MSG_BRW_LAST_CHILD, avp);
    ogs_assert(ret == 0);

    /* Set the SIP-Number-Auth-Items AVP */
    ret = fd_msg_avp_new(ogs_diam_cx_sip_number_auth_items, 0, &avp);
    ogs_assert(ret == 0);
    val.i32 = 1;
    ret = fd_msg_avp_setvalue(avp, &val);
    ogs_assert(ret == 0);
    ret = fd_msg_avp_add(req, MSG_BRW_LAST_CHILD, avp);
    ogs_assert(ret == 0);

    ret = clock_gettime(CLOCK_REALTIME, &sess_data->ts);
    ogs_assert(ret == 0);

    /* Keep a pointer to the session data for debug purpose,
     * in real life we would not need it */
    svg = sess_data;

    /* Store this value in the session */
    ret = fd_sess_state_store(aaa_swx_reg, session, &sess_data);
    ogs_assert(ret == 0);
    ogs_assert(sess_data == 0);

    /* Send the request */
    ret = fd_msg_send(&req, aaa_swx_maa_cb, svg);
    ogs_assert(ret == 0);

    /* Increment the counter */
    ogs_assert(pthread_mutex_lock(&ogs_diam_logger_self()->stats_lock) == 0);
    ogs_diam_logger_self()->stats.nb_sent++;
    ogs_assert(pthread_mutex_unlock(&ogs_diam_logger_self()->stats_lock) == 0);
}

/* Callback for incoming Multimedia-Auth-Answer messages */
static void aaa_swx_maa_cb(void *data, struct msg **msg)
{
    int ret, new;

    struct avp *avp, *avpch;
    struct avp_hdr *hdr;

    unsigned long dur;
    int error = 0;

    struct sess_state *sess_data = NULL;
    struct timespec ts;
    struct session *session;

    uint32_t result_code;
    uint32_t *err = NULL, *exp_err = NULL;

    ogs_debug("Multimedia-Auth-Answer");

    ret = clock_gettime(CLOCK_REALTIME, &ts);
    ogs_assert(ret == 0);

    /* Search the session, retrieve its data */
    ret = fd_msg_sess_get(fd_g_config->cnf_dict, *msg, &session, &new);
    if (ret != 0) {
        ogs_error("fd_msg_sess_get() failed");
        return;
    }
    if (new != 0) {
        ogs_error("fd_msg_sess_get() failed");
        return;
    }

    ret = fd_sess_state_retrieve(aaa_swx_reg, session, &sess_data);
    if (ret != 0) {
        ogs_error("fd_sess_state_retrieve() failed");
        return;
    }
    if (!sess_data) {
        ogs_error("fd_sess_state_retrieve() failed");
        return;
    }
    if ((void *)sess_data != data) {
        ogs_error("fd_sess_state_retrieve() failed");
        return;
    }

    /* Value of Result Code */
    ret = fd_msg_search_avp(*msg, ogs_diam_result_code, &avp);
    ogs_assert(ret == 0);
    if (avp) {
        ret = fd_msg_avp_hdr(avp, &hdr);
        ogs_assert(ret == 0);
        result_code = hdr->avp_value->i32;
        err = &result_code;
        ogs_debug("    Result Code: %d", hdr->avp_value->i32);
    } else {
        ret = fd_msg_search_avp(*msg, ogs_diam_experimental_result, &avp);
        ogs_assert(ret == 0);
        if (avp) {
            ret = fd_avp_search_avp(avp,
                    ogs_diam_experimental_result_code, &avpch);
            ogs_assert(ret == 0);
            if (avpch) {
                ret = fd_msg_avp_hdr(avpch, &hdr);
                ogs_assert(ret == 0);
                result_code = hdr->avp_value->i32;
                exp_err = &result_code;
                ogs_debug("    Experimental Result Code: %d", result_code);
            }
        } else {
            ogs_error("no Result-Code");
            error++;
        }
    }

    ogs_assert(err && !exp_err && result_code == ER_DIAMETER_SUCCESS);

    /* Free the message */
    ogs_assert(pthread_mutex_lock(&ogs_diam_logger_self()->stats_lock) == 0);
    dur = ((ts.tv_sec - sess_data->ts.tv_sec) * 1000000) +
        ((ts.tv_nsec - sess_data->ts.tv_nsec) / 1000);
    if (ogs_diam_logger_self()->stats.nb_recv) {
        /* Ponderate in the avg */
        ogs_diam_logger_self()->stats.avg = (ogs_diam_logger_self()->stats.avg *
            ogs_diam_logger_self()->stats.nb_recv + dur) /
            (ogs_diam_logger_self()->stats.nb_recv + 1);
        /* Min, max */
        if (dur < ogs_diam_logger_self()->stats.shortest)
            ogs_diam_logger_self()->stats.shortest = dur;
        if (dur > ogs_diam_logger_self()->stats.longest)
            ogs_diam_logger_self()->stats.longest = dur;
    } else {
        ogs_diam_logger_self()->stats.shortest = dur;
        ogs_diam_logger_self()->stats.longest = dur;
        ogs_diam_logger_self()->stats.avg = dur;
    }
    if (error)
        ogs_diam_logger_self()->stats.nb_errs++;
    else
        ogs_diam_logger_self()->stats.nb_recv++;

    ogs_assert(pthread_mutex_unlock(&ogs_diam_logger_self()->stats_lock) == 0);

    /* Display how long it took */
    if (ts.tv_nsec > sess_data->ts.tv_nsec)
        ogs_trace("in %d.%06ld sec",
                (int)(ts.tv_sec - sess_data->ts.tv_sec),
                (long)(ts.tv_nsec - sess_data->ts.tv_nsec) / 1000);
    else
        ogs_trace("in %d.%06ld sec",
                (int)(ts.tv_sec + 1 - sess_data->ts.tv_sec),
                (long)(1000000000 + ts.tv_nsec - sess_data->ts.tv_nsec) / 1000);

    ret = fd_msg_free(*msg);
    ogs_assert(ret == 0);
    *msg = NULL;

    if (sess_data->resync == true) {
        sess_data->server_assignment_type =
            OGS_DIAM_CX_SERVER_ASSIGNMENT_REGISTRATION;
        aaa_swx_send_sar(sess_data);
    } else {
        sess_data->resync = true;
        aaa_swx_send_mar(sess_data);
    }
    return;
}

void aaa_swx_send_sar(struct sess_state *sess_data)
{
    int ret;

    struct msg *req = NULL;

    struct msg_hdr *msg_header = NULL;

    struct session *session = NULL;
    struct sess_state *svg;

    struct avp *avp = NULL;
    union avp_value val;

    aaa_ue_t *aaa_ue = NULL;
    aaa_sess_t *sess = NULL;

    ogs_assert(sess_data);
    ogs_assert(sess_data->hss_host);
    ogs_info("HSS Host: %s", sess_data->hss_host);
    sess = sess_data->sess;
    ogs_assert(sess);
    aaa_ue = sess->aaa_ue;
    ogs_assert(aaa_ue);

    ogs_info("Server-Assignment-Request");

    /* Create the request */
    ret = fd_msg_new(ogs_diam_cx_cmd_sar, MSGFL_ALLOC_ETEID, &req);
    ogs_assert(ret == 0);

    ret = fd_msg_hdr(req, &msg_header);
    ogs_assert(ret == 0);
    msg_header->msg_appl = OGS_DIAM_SWX_APPLICATION_ID;

    #define OGS_DIAM_SWX_APP_SID_OPT  "app_swx"
    ret = fd_msg_new_session(req, (os0_t)OGS_DIAM_SWX_APP_SID_OPT,
            CONSTSTRLEN(OGS_DIAM_SWX_APP_SID_OPT));
    ogs_assert(ret == 0);
    ret = fd_msg_sess_get(fd_g_config->cnf_dict, req, &session, NULL);
    ogs_assert(ret == 0);

    /* Set Vendor-Specific-Application-Id AVP */
    ret = ogs_diam_message_vendor_specific_appid_set(
            req, OGS_DIAM_SWX_APPLICATION_ID);
    ogs_assert(ret == 0);

    /* Set the Auth-Session-State AVP */
    ret = fd_msg_avp_new(ogs_diam_auth_session_state, 0, &avp);
    ogs_assert(ret == 0);
    val.i32 = OGS_DIAM_AUTH_SESSION_NO_STATE_MAINTAINED;
    ret = fd_msg_avp_setvalue(avp, &val);
    ogs_assert(ret == 0);
    ret = fd_msg_avp_add(req, MSG_BRW_LAST_CHILD, avp);
    ogs_assert(ret == 0);

    /* Set Origin-Host & Origin-Realm */
    ret = fd_msg_add_origin(req, 0);
    ogs_assert(ret == 0);

    /* Set the Destination-Host AVP */
    ret = fd_msg_avp_new(ogs_diam_destination_host, 0, &avp);
    ogs_assert(ret == 0);
    val.os.data = sess_data->hss_host;
    val.os.len  = strlen((char *)sess_data->hss_host);
    ret = fd_msg_avp_setvalue(avp, &val);
    ogs_assert(ret == 0);
    ret = fd_msg_avp_add(req, MSG_BRW_LAST_CHILD, avp);
    ogs_assert(ret == 0);
    ogs_info("Destination-Host: %s", val.os.data);

    /* Set the Destination-Realm AVP */
    ret = fd_msg_avp_new(ogs_diam_destination_realm, 0, &avp);
    ogs_assert(ret == 0);
    val.os.data = (unsigned char *)(fd_g_config->cnf_diamrlm);
    val.os.len  = strlen(fd_g_config->cnf_diamrlm);
    ret = fd_msg_avp_setvalue(avp, &val);
    ogs_assert(ret == 0);
    ret = fd_msg_avp_add(req, MSG_BRW_LAST_CHILD, avp);
    ogs_assert(ret == 0);

    if (sess_data->server_assignment_type ==
            OGS_DIAM_CX_SERVER_ASSIGNMENT_REGISTRATION) {
        /* Set the User-Name AVP */
        ret = fd_msg_avp_new(ogs_diam_user_name, 0, &avp);
        ogs_assert(ret == 0);
        val.os.data = (uint8_t *)sess_data->user_name;
        val.os.len = strlen(sess_data->user_name);
        ret = fd_msg_avp_setvalue(avp, &val);
        ogs_assert(ret == 0);
        ret = fd_msg_avp_add(req, MSG_BRW_LAST_CHILD, avp);
        ogs_assert(ret == 0);
        ogs_info("User-Name: %s", val.os.data);
    }

    /* Set the Server-Assignment-Type AVP */
    ret = fd_msg_avp_new(ogs_diam_cx_server_assignment_type, 0, &avp);
    ogs_assert(ret == 0);
    val.i32 = sess_data->server_assignment_type;
    ret = fd_msg_avp_setvalue(avp, &val);
    ogs_assert(ret == 0);
    ret = fd_msg_avp_add(req, MSG_BRW_LAST_CHILD, avp);
    ogs_assert(ret == 0);

    ret = clock_gettime(CLOCK_REALTIME, &sess_data->ts);
    ogs_assert(ret == 0);

    /* Keep a pointer to the session data for debug purpose,
     * in real life we would not need it */
    svg = sess_data;

    /* Store this value in the session */
    ret = fd_sess_state_store(aaa_swx_reg, session, &sess_data);
    ogs_assert(ret == 0);
    ogs_assert(sess_data == 0);

    ogs_info("Sending Server-Assignment-Request");
    /* Send the request */
    ret = fd_msg_send(&req, aaa_swx_saa_cb, svg);
    ogs_assert(ret == 0);

    /* Increment the counter */
    ogs_assert(pthread_mutex_lock(&ogs_diam_logger_self()->stats_lock) == 0);
    ogs_diam_logger_self()->stats.nb_sent++;
    ogs_assert(pthread_mutex_unlock(&ogs_diam_logger_self()->stats_lock) == 0);
}

/* Callback for incoming Server-Assignment-Answer messages */
static void aaa_swx_saa_cb(void *data, struct msg **msg)
{
    int rv, ret, new;

    struct msg *ans = NULL;

    struct msg_hdr *msg_header = NULL;

    struct avp *avp, *avpch;
    struct avp_hdr *hdr;

    unsigned long dur;
    int error = 0;

    struct sess_state *sess_data = NULL;
    struct timespec ts;
    struct session *session;

    aaa_ue_t *aaa_ue = NULL;
    aaa_sess_t *sess = NULL;

    uint32_t result_code = OGS_DIAM_MISSING_AVP;

    ogs_info("Incoming Server-Assignment-Answer");

    ret = clock_gettime(CLOCK_REALTIME, &ts);
    ogs_assert(ret == 0);

    /* Search the session, retrieve its data */
    ret = fd_msg_sess_get(fd_g_config->cnf_dict, *msg, &session, &new);
    if (ret != 0) {
        ogs_error("fd_msg_sess_get() failed");
        return;
    }
    if (new != 0) {
        ogs_error("fd_msg_sess_get() failed");
        return;
    }

    ret = fd_sess_state_retrieve(aaa_swx_reg, session, &sess_data);
    if (ret != 0) {
        ogs_error("fd_sess_state_retrieve() failed");
        return;
    }
    if (!sess_data) {
        ogs_error("fd_sess_state_retrieve() failed");
        return;
    }

    sess = sess_data->sess;
    ogs_assert(sess);
    aaa_ue = sess->aaa_ue;
    ogs_assert(aaa_ue);

    ogs_info("Setting Result-Code for AA-Answer");
    /* Create the AA-Answer */
    ret = fd_msg_new(ogs_diam_rx_cmd_aaa, 0, &ans);
    ogs_assert(ret == 0);

    ret = fd_msg_hdr(ans, &msg_header);
    ogs_assert(ret == 0);

    /* Set the AAR session */
    ret = fd_msg_sess_set(ans, sess_data->aar_sess);
    ogs_assert(ret == 0);

    /* Value of Result Code */
    ret = fd_msg_search_avp(*msg, ogs_diam_result_code, &avp);
    ogs_assert(ret == 0);
    if (avp) {
        ret = fd_msg_avp_hdr(avp, &hdr);
        ogs_assert(ret == 0);
        result_code = hdr->avp_value->i32;
        ogs_info("    Result Code: %d", hdr->avp_value->i32);
    } else {
        ret = fd_msg_search_avp(*msg, ogs_diam_experimental_result, &avp);
        ogs_assert(ret == 0);
        if (avp) {
            ret = fd_avp_search_avp(avp,
                    ogs_diam_experimental_result_code, &avpch);
            ogs_assert(ret == 0);
            if (avpch) {
                ret = fd_msg_avp_hdr(avpch, &hdr);
                ogs_assert(ret == 0);
                result_code = hdr->avp_value->i32;
                ogs_info("    Experimental Result Code: %d", result_code);
            }
        } else {
            ogs_error("no Result-Code");
            error++;
        }
    }
    
    /* Set the Result-Code */
    if (result_code == ER_DIAMETER_SUCCESS) {
        ret = fd_msg_rescode_set(ans, 
                    (char *)"DIAMETER_SUCCESS", NULL, NULL, 1);
        ogs_assert(ret == 0);
    } else if (result_code == OGS_DIAM_AVP_UNSUPPORTED) {
        ret = fd_msg_rescode_set(ans,
                    (char *)"DIAMETER_AVP_UNSUPPORTED", NULL, NULL, 1);
        ogs_assert(ret == 0);
    } else if (result_code == OGS_DIAM_UNKNOWN_SESSION_ID) {
        ret = fd_msg_rescode_set(ans,
                    (char *)"DIAMETER_UNKNOWN_SESSION_ID", NULL, NULL, 1);
        ogs_assert(ret == 0);
    } else if (result_code == OGS_DIAM_MISSING_AVP) {
        ret = fd_msg_rescode_set(ans,
                    (char *)"DIAMETER_MISSING_AVP", NULL, NULL, 1);
        ogs_assert(ret == 0);
    } else {
        ret = ogs_diam_message_experimental_rescode_set(ans, result_code);
        ogs_assert(ret == 0);
    }

    ogs_info("Sending Authentication-Authorization-Answer");
    /* Send the answer */
    ret = fd_msg_send(&ans, NULL, NULL);
    ogs_assert(ret == 0);

    /* Add this value to the stats */
    ogs_assert(pthread_mutex_lock(&ogs_diam_logger_self()->stats_lock) == 0);
    ogs_diam_logger_self()->stats.nb_echoed++;
    ogs_assert(pthread_mutex_unlock(&ogs_diam_logger_self()->stats_lock) ==0);
    

    /* Free the message */
    ogs_assert(pthread_mutex_lock(&ogs_diam_logger_self()->stats_lock) == 0);
    dur = ((ts.tv_sec - sess_data->ts.tv_sec) * 1000000) +
        ((ts.tv_nsec - sess_data->ts.tv_nsec) / 1000);
    if (ogs_diam_logger_self()->stats.nb_recv) {
        /* Ponderate in the avg */
        ogs_diam_logger_self()->stats.avg = (ogs_diam_logger_self()->stats.avg *
            ogs_diam_logger_self()->stats.nb_recv + dur) /
            (ogs_diam_logger_self()->stats.nb_recv + 1);
        /* Min, max */
        if (dur < ogs_diam_logger_self()->stats.shortest)
            ogs_diam_logger_self()->stats.shortest = dur;
        if (dur > ogs_diam_logger_self()->stats.longest)
            ogs_diam_logger_self()->stats.longest = dur;
    } else {
        ogs_diam_logger_self()->stats.shortest = dur;
        ogs_diam_logger_self()->stats.longest = dur;
        ogs_diam_logger_self()->stats.avg = dur;
    }
    if (error)
        ogs_diam_logger_self()->stats.nb_errs++;
    else
        ogs_diam_logger_self()->stats.nb_recv++;

    ogs_assert(pthread_mutex_unlock(&ogs_diam_logger_self()->stats_lock) == 0);

    /* Display how long it took */
    if (ts.tv_nsec > sess_data->ts.tv_nsec)
        ogs_trace("in %d.%06ld sec",
                (int)(ts.tv_sec - sess_data->ts.tv_sec),
                (long)(ts.tv_nsec - sess_data->ts.tv_nsec) / 1000);
    else
        ogs_trace("in %d.%06ld sec",
                (int)(ts.tv_sec + 1 - sess_data->ts.tv_sec),
                (long)(1000000000 + ts.tv_nsec - sess_data->ts.tv_nsec) / 1000);

    ret = fd_msg_free(*msg);
    ogs_assert(ret == 0);
    *msg = NULL;

    rv = sess_data->gtp_send(sess, sess_data->handover_ind);
    ogs_assert(rv == OGS_OK);

    state_cleanup(sess_data, NULL, NULL);
}

int aaa_swx_init(void)
{
    int ret;
    struct disp_when data;

    ogs_thread_mutex_init(&sess_state_mutex);
    ogs_pool_init(&sess_state_pool, ogs_app()->pool.sess);

    /* Install objects definitions for this application */
    ret = ogs_diam_swx_init();
    ogs_assert(ret == 0);

    /* Create handler for sessions */
    ret = fd_sess_handler_create(&aaa_swx_reg, &state_cleanup, NULL, NULL);
    ogs_assert(ret == 0);

    /* Fallback CB if command != unexpected message received */
    memset(&data, 0, sizeof(data));
    data.app = ogs_diam_swx_application;

    ret = fd_disp_register(aaa_swx_fb_cb, DISP_HOW_APPID, &data, NULL,
                &hdl_swx_fb);
    ogs_assert(ret == 0);

    /* Advertise the support for the application in the peer */
    ret = fd_disp_app_support(ogs_diam_swx_application, ogs_diam_vendor, 1, 0);
    ogs_assert(ret == 0);

    return 0;
}

void aaa_swx_final(void)
{
    int ret;

    ret = fd_sess_handler_destroy(&aaa_swx_reg, NULL);
    ogs_assert(ret == OGS_OK);

    if (hdl_swx_fb)
        (void) fd_disp_unregister(&hdl_swx_fb, NULL);

    ogs_pool_final(&sess_state_pool);
    ogs_thread_mutex_destroy(&sess_state_mutex);
}
