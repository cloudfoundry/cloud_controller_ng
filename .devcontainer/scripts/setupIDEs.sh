#!/bin/bash
set -Eeuo pipefail
# shellcheck disable=SC2064
trap "pkill -P $$" EXIT

# Setup IDEs
cp -a -f .devcontainer/configs/vscode/.vscode .
cp -a -f .devcontainer/configs/intellij/.idea .

trap "" EXIT