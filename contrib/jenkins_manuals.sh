#!/bin/sh -ex

cd docs/manuals
make

if [ "$PUBLISH" = "1" ]; then
	make publish
fi
