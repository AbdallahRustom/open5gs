-module(osmo_epdg).

-export([main/1]).

main(_Args) ->
	application:ensure_all_started(?MODULE),
	timer:sleep(infinity).
