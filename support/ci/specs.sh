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
  #cat ./logs/*.log
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

# TODO
#export HAB_TEST_DEBUG=true

adduser --system hab || true
addgroup --system hab || true

mkdir -p /hab/cache/keys
echo "MONDAY GENERATING KEY"
hab origin key generate travis_testing_key
echo "MONDAY CAT ALL KEY"
ls -la /hab/cache/keys
cat /hab/cache/keys/*

# TODO
# https://docs.travis-ci.com/user/pull-requests
if [ "${TRAVIS_PULL_REQUEST}" = "false" ]; then
    run_tests
else
    run_tests
fi
