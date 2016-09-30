#!/bin/bash
set -e

BOOTSTRAP_DIR=/root/travis_bootstrap
TEST_BIN_DIR=/root/hab_bins
HAB_DOWNLOAD_URL="https://api.bintray.com/content/habitat/stable/linux/x86_64/hab-%24latest-x86_64-linux.tar.gz?bt_package=hab-x86_64-linux"

mkdir -p ${BOOTSTRAP_DIR}

# make sure it's clean!
rm -rf ${TEST_BIN_DIR}
mkdir -p ${TEST_BIN_DIR}
mkdir -p /hab/cache/keys

wget -O hab.tar.gz "${HAB_DOWNLOAD_URL}"
tar xvzf ./hab.tar.gz --strip 1 -C ${BOOTSTRAP_DIR}

TRAVIS_HAB=${BOOTSTRAP_DIR}/hab
${TRAVIS_HAB} origin key generate hab_travis
cat /hab/cache/keys/*

# REQUIRED to build the hab binary outside of core
export HAB_ORIGIN=hab_travis
# pretend we're not using sudo
unset SUDO_USER

# we have to cd here so hab's plan.sh can see the VERSION file
${TRAVIS_HAB} studio build components/hab
${TRAVIS_HAB} studio build components/sup

# install the artifacts
${TRAVIS_HAB} pkg install ./results/*.hart

# copy the binaries out built packages
# this will most likely fail if you have compiled hab + sup more than once,
# hence the rm -rf ${TEST_BIN_DIR} above
find /hab/pkgs/hab_travis/hab/ -type f -name hab -exec cp {} ${TEST_BIN_DIR} \;
find /hab/pkgs/hab_travis/hab-sup/ -type f -name hab-sup -exec cp {} ${TEST_BIN_DIR} \;

echo "SHIPPING OUT TO TOPEKA"
./test/test.sh
