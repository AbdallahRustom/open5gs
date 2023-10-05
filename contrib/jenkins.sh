#!/bin/sh -ex

rebar3 compile
rebar3 escriptize
rebar3 eunit
