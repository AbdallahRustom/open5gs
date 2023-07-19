= osmo-ePDG =

Implement an ePDG with an embedded AAA server.
osmo-ePDG also requires a modify strongswan.

* [UE] <-> [strongswan] <-> [osmo-ePDG] <> [HSS]
                                        <> [PGW]

== Building ==

Install erlang and rebar3 packages (not "rebar", that's version 2! You may need
to compile it from source in some distros).

$ rebar3 compile
$ rebar3 escriptize

== Testing ==

Unit tests can be run this way:
$ rebar3 eunit

== Running ==

Once osmo\_epdg is built, you can start it this way:

$ rebar3 shell

In the erlang shell:
```
1> osmo_epdg:start().
```

== Configuration ==

$ rebar3 shell --config ./examples/sys.config
```
1> osmo_epdg:start().
```

