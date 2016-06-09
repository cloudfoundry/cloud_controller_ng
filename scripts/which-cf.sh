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

  local capi_release_sha
  local cc_sha

  pushd "${CF_RELEASE_DIR}" > /dev/null
    set +e
    capi_release_sha=$(git ls-tree "${branch}" src/capi-release | grep -E -o --color=never "[0-9a-f]{40}")
    set -e
  popd > /dev/null

  if [[ -n "${capi_release_sha}" ]]; then
    pushd "${CAPI_RELEASE_DIR}" > /dev/null
      cc_sha=$(git ls-tree "${capi_release_sha}" src/cloud_controller_ng | grep -E -o --color=never "[0-9a-f]{40}")
    popd > /dev/null
  else
    pushd "${CF_RELEASE_DIR}" > /dev/null
      cc_sha=$(git ls-tree "${branch}" src/cloud_controller_ng | grep -E -o --color=never "[0-9a-f]{40}")
    popd > /dev/null
  fi

  pushd "${CC_DIR}" > /dev/null
    set +e
    git merge-base --is-ancestor "${search_sha}" "${cc_sha}"
    exists=$?
    set -e
  popd > /dev/null
}

function first_release_with_sha {
  declare sha=$1

  local tag
  release=""

  pushd ~/workspace/cf-release > /dev/null
    for tag in $(git tag | grep -E "v[0-9]{3}$" | sort -n -t v -k 2); do
      exists_on_ref "${tag}" "${sha}"

      if [[ "${exists}" -eq 0 ]]; then
        release=$tag
        return
      fi
    done
  popd > /dev/null
}

function display_pre_release_branches_with_sha {
  declare search_sha=$1

  declare -a branches=("origin/master" "origin/release-candidate" "origin/acceptance-deployed" "origin/develop")
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
  first_release_with_sha "${SEARCH_SHA}"

  if [[ -n "${release}" ]]; then
    local result
    result="$(tput setaf 2)$(tput bold)$release$(tput sgr0)"
    echo "$(tput setaf 1)First CF release:$(tput sgr0)" "${result}"
  else
    echo "$(tput setaf 1)Has not been released$(tput sgr0)"
    display_pre_release_branches_with_sha "${SEARCH_SHA}"
  fi
}

main
