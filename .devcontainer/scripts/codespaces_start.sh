#!/bin/bash
set -Eeuxo pipefail
# shellcheck disable=SC2064
trap "pkill -P $$" EXIT

# Setup IDEs
./.devcontainer/scripts/setupIDEs.sh

# Setup DBs and CC Config File
./.devcontainer/scripts/setupDevelopmentEnvironment.sh

trap "" EXIT