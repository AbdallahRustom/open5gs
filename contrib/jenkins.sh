#!/bin/sh -ex

make clean || true
make
make check
