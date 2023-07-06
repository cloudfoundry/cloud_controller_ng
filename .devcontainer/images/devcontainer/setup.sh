#!/bin/bash
set -Eeuo pipefail
# shellcheck disable=SC2064
trap "pkill -P $$" EXIT

setupAptPackages () {
  # CF CLI is not available for aarch64 :(
  if [[ $(uname -m) == aarch64 ]]; then
    PACKAGES="postgresql-client postgresql-client-common mariadb-client ruby-dev"
  else
    PACKAGES="cf8-cli postgresql-client postgresql-client-common mariadb-client ruby-dev"
  fi

  wget -q -O - https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key | sudo apt-key add -
  echo "deb https://packages.cloudfoundry.org/debian stable main" | sudo tee /etc/apt/sources.list.d/cloudfoundry-cli.list
  sudo apt-get update
  export DEBIAN_FRONTEND="noninteractive" && echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections
  sudo apt-get install -o Dpkg::Options::="--force-overwrite" $PACKAGES -y
}

setupRubyGems () {
  gem install cf-uaac
}

setupCredhubCli () {
  set -x
  wget "$(curl -s https://api.github.com/repos/cloudfoundry/credhub-cli/releases/latest |
  jq -r '.assets[] | select(.name|match("credhub-linux.*")) | .browser_download_url')" -O /tmp/credhub.tar.gz
  cd /tmp
  sudo tar -xzf /tmp/credhub.tar.gz && sudo rm -f /tmp/credhub.tar.gz && sudo mv /tmp/credhub /usr/bin
}

setupYqCli () {
  sudo wget "$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest |
  jq -r '.assets[] | select(.name|match("linux_amd64$")) | .browser_download_url')" -O /usr/bin/yq
  sudo chmod +x /usr/bin/yq
}

echo """
export COMPOSE_DOCKER_CLI_BUILD=1
export DOCKER_BUILDKIT=1
""" > ~/.bashrc

setupAptPackages
setupRubyGems
setupCredhubCli
setupYqCli

trap "" EXIT