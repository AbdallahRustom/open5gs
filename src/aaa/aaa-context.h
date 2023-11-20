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

#ifndef AAA_CONTEXT_H
#define AAA_CONTEXT_H

#include "ogs-gtp.h"
#include "ogs-diameter-cx.h"
#include "ogs-diameter-rx.h"
#include "ogs-diameter-s6b.h"
#include "ogs-diameter-swx.h"
#include "ogs-dbi.h"

#ifdef __cplusplus
extern "C" {
#endif

extern int __aaa_log_domain;

#undef OGS_LOG_DOMAIN
#define OGS_LOG_DOMAIN __aaa_log_domain

typedef struct _aaa_context_t {
    const char          *diam_conf_path;/* AAA Diameter conf path */
    ogs_diam_config_t   *diam_config;   /* AAA Diameter config */
} aaa_context_t;


typedef struct aaa_ue_s {
    /* IMSI */
    uint8_t imsi[OGS_MAX_IMSI_LEN];
    int imsi_len;
    char imsi_bcd[OGS_MAX_IMSI_BCD_LEN+1];

    uint8_t k[OGS_KEY_LEN];
    const char *k_string;
    uint8_t opc[OGS_KEY_LEN];
    const char *opc_string;

    uint8_t rand[OGS_RAND_LEN];

    ogs_list_t sess_list;
} aaa_ue_t;

typedef struct aaa_sess_s {
    ogs_lnode_t     lnode;          /**< A node of list_t */
    uint32_t        index;

    char            *swx_sid;        /* SWx Session ID */

    bool            epc;            /**< EPC or 5GC */

    /* PDN Configuration */
    ogs_session_t session;

    aaa_ue_t *aaa_ue;
} aaa_sess_t;

struct sess_state {
    os0_t       sid;                /* S6B Session-Id */
    
    os0_t       hss_host;          /* HSS Host */
    os0_t       smf_host;          /* SMF Host */

    aaa_sess_t *sess;
    bool handover_ind;
    int (*gtp_send)(aaa_sess_t *sess, bool handover_ind);

    struct session *aar_sess;

    char *user_name;

    bool resync;

    int server_assignment_type;

    struct timespec ts;             /* Time of sending the message */
};

void aaa_context_init(void);
void aaa_context_final(void);
aaa_context_t *aaa_self(void);

int aaa_context_parse_config(void);

aaa_ue_t *aaa_ue_new(void);
aaa_sess_t *aaa_sess_add_by_apn(aaa_ue_t *aaa_ue, char *apn, uint8_t rat_type);

#ifdef __cplusplus
}
#endif

#endif /* AAA_CONTEXT_H */
