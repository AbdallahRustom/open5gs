#!/bin/sh -e

# execute the script from the top dir of this repository to generate
# a build_dep.tar.gz for building with debian/OBS

if [ ! -e rebar.config ] ; then
	echo "Please execute $0 from the top directory of the osmo-epdg directory"
	exit 1
fi

set -x
rm -rf _checkouts _build
rebar3 get-deps
mkdir _checkouts
mv ./_build/default/lib/* _checkouts/
mv ./_build/default/plugins/* _checkouts/
# delete erlang bytecode
find _checkouts/ -iname '*beam' -delete
tar czf build_dep.tar.gz ./_checkouts
