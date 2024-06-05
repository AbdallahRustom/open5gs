% Misc helpers
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
%
-module(misc).
-author('Pau Espin Pedrol <pespin@sysmocom.de>').

-export([spawn_wait_ret/2]).

%% Calls Fun on a spawned monitored process and returns Fun ret.
%% If spawned process crashes, return DefaultRet.
spawn_wait_ret(Fun, DefaultRet) ->
        MyPID=self(),
        {Pid, MRef} = spawn_monitor(fun() ->
                                        Ret = Fun(),
                                        MyPID ! {self(), Ret}
                                    end),
        receive
        {'DOWN', MRef, process, _, _Reason} ->
            DefaultRet;
        {Pid, Ret} ->
            erlang:demonitor(MRef, [flush]),
            Ret
        end.