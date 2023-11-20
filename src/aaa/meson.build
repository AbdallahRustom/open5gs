# Copyright (C) 2019 by Sukchan Lee <acetcom@gmail.com>

# This file is part of Open5GS.

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

libaaa_sources = files('''
    aaa-context.h
    aaa-fd-path.h

    aaa-init.c
    aaa-context.c

    aaa-s6b-path.c
    aaa-swx-path.c

    aaa-fd-path.c
'''.split())

libaaa = static_library('aaa',
    sources : libaaa_sources,
    dependencies : [libapp_dep,
                    libdbi_dep,
                    libdiameter_s6b_dep,
                    libdiameter_swx_dep,
                    libgtp_dep],
    install : false)

libaaa_dep = declare_dependency(
    link_with : libaaa,
    dependencies : [libapp_dep,
                    libdbi_dep,
                    libdiameter_s6b_dep,
                    libdiameter_swx_dep,
                    libgtp_dep])

aaa_sources = files('''
    app-init.c
    ../main.c
'''.split())

executable('open5gs-aaad',
    sources : aaa_sources,
    c_args : '-DDEFAULT_CONFIG_FILENAME="@0@/aaa.yaml"'.format(open5gs_sysconfdir),
    include_directories : srcinc,
    dependencies : libaaa_dep,
    install_rpath : libdir,
    install : true)
