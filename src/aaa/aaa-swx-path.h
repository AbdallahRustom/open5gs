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

#ifndef AAA_SWX_PATH_H
#define AAA_SWX_PATH_H

#ifdef __cplusplus
extern "C" {
#endif

#include "aaa-context.h"

void aaa_swx_send(aaa_sess_t *sess, bool handover_ind,
        int (*gtp_send)(aaa_sess_t *sess, bool handover_ind));
void aaa_swx_send_sar(struct sess_state *sess_data);

#ifdef __cplusplus
}
#endif

#endif /* AAA_SWX_PATH_H */
