#!/bin/bash
set -Eeuo pipefail
# shellcheck disable=SC2064
trap "pkill -P $$" EXIT

setupAptPackages () {
  PACKAGES="cf8-cli postgresql-client postgresql-client-common mariadb-client"

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
  local arch_pattern
  case "$(uname -m)" in
    "x86_64")
      arch_pattern="credhub-linux-amd64.*"
      ;;
    "aarch64" | "arm64")
      arch_pattern="credhub-linux-arm64.*"
      ;;
    *)
      echo "Unsupported architecture for credhub-cli: $(uname -m)"
      exit 1
      ;;
  esac

  local download_url
  download_url=$(curl -s https://api.github.com/repos/cloudfoundry/credhub-cli/releases/latest | jq -r ".assets[] | select(.name|test(\"$arch_pattern\")) | .browser_download_url" | head -n 1)

  if [ -z "$download_url" ]; then
    echo "No arm64 release found, trying amd64..."
    arch_pattern="credhub-linux-amd64.*"
    download_url=$(curl -s https://api.github.com/repos/cloudfoundry/credhub-cli/releases/latest | jq -r ".assets[] | select(.name|test(\"$arch_pattern\")) | .browser_download_url" | head -n 1)
  fi

  if [ -z "$download_url" ]; then
    echo "Failed to get credhub-cli download URL for $(uname -m)"
    exit 1
  fi

  wget "$download_url" -O /tmp/credhub.tar.gz
  cd /tmp
  sudo tar -xzf /tmp/credhub.tar.gz && sudo rm -f /tmp/credhub.tar.gz && sudo mv /tmp/credhub /usr/bin
}

setupYqCli () {
  local arch_pattern
  case "$(uname -m)" in
    "x86_64")
      arch_pattern="linux_amd64$"
      ;;
    "aarch64" | "arm64")
      arch_pattern="linux_arm64$"
      ;;
    *)
      echo "Unsupported architecture for yq: $(uname -m)"
      exit 1
      ;;
  esac

  local download_url
  download_url=$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | jq -r ".assets[] | select(.name|test(\"$arch_pattern\")) | .browser_download_url" | head -n 1)

  if [ -z "$download_url" ]; then
    echo "Failed to get yq download URL for $(uname -m)"
    exit 1
  fi

  sudo wget "$download_url" -O /usr/bin/yq
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

# Setup User Permissions
sudo groupadd docker
sudo usermod -aG docker "vscode"
sudo chown -R vscode:vscode /usr/local/rvm/gems

trap "" EXIT
