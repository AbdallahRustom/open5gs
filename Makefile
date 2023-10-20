all: build

build:
	rebar3 compile
	rebar3 escriptize

run: build
	ERL_FLAGS='-config config/sys.config' _build/default/bin/osmo-epdg

shell: build
	rebar3 shell --config ./config/sys.config

check:
	rebar3 eunit

clean:
# Avoid running rebar3 clean if _build doesn't exist, since it would try
# to fetch deps from the Internet and that may not be avaialble when in
# OBS build.
ifneq ("$(wildcard _build/.*)", "")
	rebar3 clean
	rm -rf _build/
else
	rm -f src/diameter_*.erl
endif
