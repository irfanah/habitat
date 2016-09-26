#!/bin/bash
#
# # License and Copyright
#
# Copyright: Copyright (c) 2016 Chef Software, Inc.
# License: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e
# TODO
set -x

echo "####################################################################"
echo "####################################################################"
echo "####################################################################"
echo "####################################################################"
echo "####################################################################"
echo "####################################################################"

# The list of all specs to run after basic and env tests are run.
# WITHOUT .rb suffix.
all_specs=(crypto)

# sadly, this is NOT a banner of a cat. But, with a pull request,
# YOU could make it so.
cat banner

# load in common test env vars
if [ "${TRAVIS}" = "true" ]; then
    export PATH=$PATH:/home/travis/build/habitat-sh/habitat/target/debug/
    # TODO: move this outside of test.sh?
    HAB=/home/travis/build/habitat-sh/habitat/target/debug/hab
    #export DEBUG=true

    echo "TACOS!!!"
    mkdir -p /hab/cache/keys
    chmod 777 /hab/cache/keys

    #${HAB} pkg install core/hab-studio
    #p=$(${HAB} pkg path core/hab-studio)
    #sed -i 's/set -eu/set -eux/' "${p}/bin/hab-studio"
    #sed -i '23iecho "TACOS: $\{hab\}"' "${p}/bin/hab-studio"
    #sed -i 's/set +e/set -eux/' "${p}/libexec/hab-studio-type-default.sh"
    echo "INSTALLING HAB-STUDIO"
    ${HAB} pkg install core/hab-studio
    ls -latr /hab/cache/keys
    cat /hab/cache/keys/*
    echo "DONE INSTALLING HAB-STUDIO"
    hab origin key export core --type public
    echo "DONE EXPORTING KEY"

    export HAB_CACHE_KEY_PATH=/hab/cache/keys

else
    HAB=/bin/hab
fi

export INSPEC_PACKAGE=core/inspec
export RUBY_PACKAGE=core/ruby
export RUBY_VERSION="2.3.0"
export BUNDLER_PACKAGE=core/bundler

install_package() {
    pkg_to_install=$1
    description=$2

    echo "» Installing ${description}"
    ${HAB} pkg install "${pkg_to_install}"
    echo "★ Installed ${description}"
}

mkdir -p ./logs
echo "Installing Habitat testing packages..."

install_package ${INSPEC_PACKAGE} "Chef Inspec"
install_package ${BUNDLER_PACKAGE} "Bundler"

INSPEC_BUNDLE="$(${HAB} pkg path $INSPEC_PACKAGE)/bundle"
GEM_HOME="${INSPEC_BUNDLE}/ruby/${RUBY_VERSION}"
GEM_PATH="$(${HAB} pkg path ${RUBY_PACKAGE})/lib/ruby/gems/${RUBY_VERSION}:$(${HAB} pkg path ${BUNDLER_PACKAGE}):${GEM_HOME}"
LD_LIBRARY_PATH="$LD_LIBRARY_PATH:$(${HAB} pkg path core/gcc-libs)/lib)"
export INSPEC_BUNDLE
export GEM_HOME
export GEM_PATH
export LD_LIBRARY_PATH


INSPEC="${HAB} pkg exec ${INSPEC_PACKAGE} inspec"
RSPEC="${HAB} pkg exec ${INSPEC_PACKAGE} rspec"


# This is required for rspec to pickup extra options via Inspec
SPEC_OPTS="--color --require spec_helper --format documentation"
export SPEC_OPTS


running_sups=$(pgrep hab-sup | wc -l)
if [ "$running_sups" -gt 0 ]; then
    echo "There are running Habitat supervisors, cannot continue testing"
    exit 1
fi

# TODO
if [ ! -z "$1" ]
  then
    echo "Running {$1}"
  else
    echo "Running all tests"
fi

####################################################################
# Run the tests!
####################################################################

echo "» Running tests"
test_start=$(date)
echo "☛ ${test_start}"

echo "» Checking for a clean test environment"
${INSPEC} exec ./hab_inspec/controls/clean_env.rb

env
echo "» Checking basic build/install/run functionality"
${RSPEC} ./spec/basic.rb

for s in "${all_specs[@]}"; do
    echo "» Running specs from ${s}"
    ${RSPEC} "./spec/${s}.rb"
done


####################################################################
# We're finished, report elapsed time
####################################################################
test_finish=$(date)
echo "☛ ${test_finish}"
echo "★ Finished"
