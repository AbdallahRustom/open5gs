all: build

build:
	rebar3 compile
	rebar3 escriptize

run: build
	ERL_FLAGS='-config config/sys.config' _build/default/bin/osmo-epdg

check:
	rebar3 eunit

clean:
	rm -rf _build/
