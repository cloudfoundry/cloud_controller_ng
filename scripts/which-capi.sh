#!/usr/bin/env bash

set -eu
set -o pipefail

if [ $# == 0 ]; then
    echo "Usage: $0 SHA"
    exit 1
fi

readonly CF_RELEASE_DIR=${CF_RELEASE_DIR:-~/workspace/cf-release}
readonly CAPI_RELEASE_DIR="${CF_RELEASE_DIR}/src/capi-release"
readonly CC_DIR="${CAPI_RELEASE_DIR}/src/cloud_controller_ng"
readonly SEARCH_SHA=$1

function update_repos {
  pushd "${CF_RELEASE_DIR}" > /dev/null
    git fetch
  popd > /dev/null

  pushd "${CAPI_RELEASE_DIR}" > /dev/null
    git fetch
  popd > /dev/null

  pushd "${CC_DIR}" > /dev/null
    git fetch
  popd > /dev/null
}

function exists_on_ref {
  declare branch=$1 search_sha=$2

  local cc_sha

  pushd "${CAPI_RELEASE_DIR}" > /dev/null
    set +e
    cc_sha=$(git ls-tree "${branch}" src/cloud_controller_ng | grep -E -o --color=never "[0-9a-f]{40}")
    set -e
  popd > /dev/null

  pushd "${CC_DIR}" > /dev/null
    set +e
    git merge-base --is-ancestor "${search_sha}" "${cc_sha}"
    exists=$?
    set -e
  popd > /dev/null
}

function display_pre_release_branches_with_sha {
  declare search_sha=$1

  declare -a branches=("origin/ci-passed" "origin/master" )
  local branch
  local result

  declare found_one=1
  for branch in "${branches[@]}"; do
    exists_on_ref "${branch}" "${search_sha}"

    if [[ "${exists}" -eq 0 ]]; then
      result="$(tput setaf 2)$(tput bold)found$(tput sgr0)"
      found_one=0
    else
      result="$(tput setaf 3)$(tput bold)not found$(tput sgr0)"
    fi

    printf "%-40s %s\n" "$(tput setaf 1)${branch}:$(tput sgr0)" "${result}"
  done

  if [[ "${found_one}" -eq 1 ]]; then
    if which dishy > /dev/null; then
      echo ""
      echo $(dishy fail)
    fi
  fi
}

function main {
  update_repos
  display_pre_release_branches_with_sha "${SEARCH_SHA}"
}

main
