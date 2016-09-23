#!/bin/bash

git log HEAD~1..HEAD | grep -q '!!! Temporary Commit !!!'
is_tmp_commit=$?

# When we're on a temporary commit, don't do anything.
if [[ $is_tmp_commit = 0 ]]; then
  exit 0
fi

#set -e

run_tests() {
  cd test || exit
  ./test.sh
  cat ./logs/*.log
}

# set these here so Travis is happy, setting them in .travis.yml + sudo
# makes the tests unhappy.
export COMPONENTS=bin
export LIBSODIUM=/home/travis/pkgs/libsodium/1.0.8
export LIBARCHIVE=/home/travis/pkgs/libarchive/3.2.0
export PKG_CONFIG_PATH="$PKG_CONFIG_PATH:$LIBARCHIVE/lib/pkgconfig:$LIBSODIUM/lib/pkgconfig"
export LD_LIBRARY_PATH="LD_LIBRARY_PATH:$LIBARCHIVE/lib:$LIBSODIUM/lib"
export PATH=$PATH:/home/travis/build/habitat-sh/habitat/target/debug/

export HAB_TEST_BIN_DIR=/home/travis/build/habitat-sh/habitat/target/debug
#cp ${HAB_TEST_BIN_DIR}/hab /usr/bin/hab
#cp ${HAB_TEST_BIN_DIR}/hab-sup /usr/bin/hab-sup

sed -i '23iecho "TACOS: $\{hab\}"' /hab/pkgs/core/hab-studio/0.9.3/20160916192516/libexec/hab-studio-type-default.sh

echo "BUSYBOX!"
command -v busybox


# TODO
export HAB_TEST_DEBUG=true

adduser --system hab || true
addgroup --system hab || true

mkdir /hab
chown hab:hab /hab
hab origin key generate travis_testing_key

# TODO
# https://docs.travis-ci.com/user/pull-requests
if [ "${TRAVIS_PULL_REQUEST}" = "false" ]; then
    run_tests
else
    run_tests
fi
