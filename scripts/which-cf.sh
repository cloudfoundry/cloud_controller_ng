#!/usr/bin/env bash

set -eu
set -o pipefail

if [ $# == 0 ]; then
    echo "Usage: $0 SHA"
    exit 1
fi

CF_RELEASE_DIR=${CF_RELEASE_DIR:-~/workspace/cf-release}
CAPI_RELEASE_DIR="${CF_RELEASE_DIR}/src/capi-release"
CC_DIR="$(cd "$(dirname "$0")" && pwd)"
SEARCH_SHA=$1

declare -a branches=("origin/master" "origin/release-candidate" "origin/acceptance-deployed" "origin/runtime-passed" "origin/runtime-deployed" "origin/develop")

function update_repos {
  pushd ${CF_RELEASE_DIR} > /dev/null
    git fetch
  popd > /dev/null

  pushd ${CAPI_RELEASE_DIR} > /dev/null
    git fetch
  popd > /dev/null

  pushd ${CC_DIR} > /dev/null
    git fetch
  popd > /dev/null
}

function main {
  update_repos

  local capi_release_sha
  local cc_sha
  local exists
  local result

  for branch in "${branches[@]}"
  do
    pushd ${CF_RELEASE_DIR} > /dev/null
      capi_release_sha=$(git ls-tree ${branch} src/capi-release | grep -E -o --color=never "[0-9a-f]{40}")
    popd > /dev/null

    pushd ${CAPI_RELEASE_DIR} > /dev/null
      cc_sha=$(git ls-tree ${capi_release_sha} src/cloud_controller_ng | grep -E -o --color=never "[0-9a-f]{40}")
    popd > /dev/null

    pushd ${CC_DIR} > /dev/null
      set +e
      git merge-base --is-ancestor ${SEARCH_SHA} ${cc_sha}
      exists=$?
      set -e
    popd > /dev/null

    if [[ ${exists} -eq 0 ]]; then
      result="$(tput setaf 2)$(tput bold)found$(tput sgr0)"
    else
      result="$(tput setaf 3)$(tput bold)not found$(tput sgr0)"
    fi

    printf "%-40s %s\n" "$(tput setaf 1)${branch}:$(tput sgr0)" "${result}"
  done
}

main

exit 0
