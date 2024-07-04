#!/bin/bash
set -euo pipefail

repo_root="$(git rev-parse --show-toplevel)"

pushd "$repo_root"
    export DOC_CHANGE_COMMIT="$(git log -1 --format=format:%h -- docs/v2)"
    git checkout $DOC_CHANGE_COMMIT -- config/version_v2
    export DOC_CHANGE_VERSION="$(cat config/version_v2)"
    git checkout -- config/version_v2
popd

erb index.html.erb > index.html
