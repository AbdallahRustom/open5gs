all: build

build:
	rebar3 compile
	rebar3 escriptize

run: build
	_build/default/bin/osmo-epdg

check:
	rebar3 eunit

clean:
	rm -rf _build/
