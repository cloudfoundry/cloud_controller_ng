#!/usr/bin/env bash
set -e -x

# This script must be run with an argument: either a final release number or 'release-candidate'
if [[ $# -eq 0 ]]; then
  echo "You need to provide the version number as the first argument"
  exit 0
fi

readonly ROOT_DIR="$(dirname "$0")/.."
readonly VERSION=$1

function build_docs() {
  pushd "${ROOT_DIR}/docs" > /dev/null
    bundle

    touch source/versionfile
    echo "${VERSION}" > source/versionfile

    bundle exec middleman build

    rm -f source/versionfile
  popd > /dev/null
}

function abort_on_existing_version() {
  if [[ ${VERSION} != 'release-candidate' && -d "version/${VERSION}" ]]; then
    echo "That version already exists."
    exit 1
  fi
}

function write_versions_json() {
  # Update the versions.json
    # - Grabs all the folder names
    # - Rewrites the versions.json
  declare version_list=''
  local dirs
  local dir
  dirs=$(ls -l version | egrep '^d' | awk '{print $9}' | sort -n -r)

  rm -f versions.json

  echo -e '{
  \t"versions": [' > versions.json

  for dir in ${dirs}
  do
    version_list="${version_list}\t\t\"${dir}\",\n"
  done

  # this crazy bash removes the trailing newline and , so that our array is valid json, there's probably a better way
  echo -e "${version_list%???}" >> versions.json

  echo -e '\t]
  }' >> versions.json
}

function update_index_html() {
  if [[ ${VERSION} != 'release-candidate' ]]; then
    cat <<INDEX > index.html
---
redirect_to: version/${VERSION}/index.html
---
INDEX
  fi
}

function remove_old_release_candidate() {
  if [[ ${VERSION} == 'release-candidate' ]]; then
    rm -rf version/release-candidate
  fi
}

function push_docs() {
  git add index.html --ignore-errors
  git add versions.json
  git add "version/${VERSION}"

  if [[ "$(git diff --name-only --staged)" == '' ]]; then
    echo "No changes to the docs. Nothing to publish"
    return
  fi

  git commit -m "Bump v3 API docs version ${VERSION}"

  git remote add origin-ssh git@github.com:cloudfoundry/cloud_controller_ng.git
  git push origin-ssh gh-pages
}

function add_new_docs() {
  mkdir -p "version/${VERSION}"
  mv docs/build/* "version/${VERSION}"
  rm -rf docs/build
}

function main() {
  build_docs

  pushd "${ROOT_DIR}" > /dev/null
    git checkout gh-pages
    git pull --ff-only

    abort_on_existing_version
    remove_old_release_candidate
    add_new_docs
    update_index_html
    write_versions_json
    push_docs

    git checkout master
  popd > /dev/null
}

main
