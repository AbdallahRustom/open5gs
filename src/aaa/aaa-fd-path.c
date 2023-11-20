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

#include "ogs-crypt.h"

#include "aaa-context.h"
#include "aaa-fd-path.h"

int aaa_fd_init(void)
{
    int rv;

    rv = ogs_diam_init(FD_MODE_SERVER,
                aaa_self()->diam_conf_path, aaa_self()->diam_config);
    ogs_assert(rv == 0);

    rv = ogs_diam_cx_init();
    ogs_assert(rv == 0);
    rv = ogs_diam_rx_init();
    ogs_assert(rv == 0);

    rv = aaa_s6b_init();
    ogs_assert(rv == OGS_OK);
    rv = aaa_swx_init();
    ogs_assert(rv == OGS_OK);

    rv = ogs_diam_start();
    ogs_assert(rv == 0);

    return OGS_OK;
}

void aaa_fd_final(void)
{
    aaa_s6b_final();
    aaa_swx_final();

    ogs_diam_final();
}
