#!/bin/bash
set -eo pipefail

setupAptPackages () {
  PACKAGES="postgresql-client postgresql-client-common mariadb-client ruby-dev direnv"

  echo "Installing packages: $PACKAGES"
  sudo apt-get update
  export DEBIAN_FRONTEND="noninteractive" && echo 'debconf debconf/frontend select Noninteractive' | sudo debconf-set-selections
  sudo apt-get install -o Dpkg::Options::="--force-overwrite" $PACKAGES -y

  echo "✓ Packages installed successfully"
}

setupCfCli () {
  echo "Installing CF CLI v8..."
  ARCH=$(uname -m)

  if [[ "$ARCH" == "x86_64" ]]; then
    CF_ARCH="linux64"
  elif [[ "$ARCH" == "aarch64" ]]; then
    CF_ARCH="linuxarm64"
  else
    echo "⚠️  Unsupported architecture: $ARCH"
    return 1
  fi

  local tmp_dir=$(mktemp -d)
  cd "$tmp_dir"

  echo "Downloading CF CLI for ${CF_ARCH}..."
  if curl -L -f "https://packages.cloudfoundry.org/stable?release=${CF_ARCH}-binary&version=v8&source=github" | tar -xz; then
    sudo mv cf8 /usr/local/bin/cf8
    sudo chmod +x /usr/local/bin/cf8
    sudo ln -sf /usr/local/bin/cf8 /usr/local/bin/cf
    echo "✓ CF CLI installed: $(cf version)"
  else
    echo "⚠️  CF CLI installation failed"
    return 1
  fi

  cd - > /dev/null
  rm -rf "$tmp_dir"
}

setupRubyGems () {
  # Install development tools
  gem install solargraph cf-uaac
  echo "✓ Ruby gems installed (solargraph, cf-uaac)"
}

setupCredhubCli () {
  echo "Installing credhub CLI..."
  local download_url
  download_url=$(curl -s https://api.github.com/repos/cloudfoundry/credhub-cli/releases/latest | jq -r '.assets[] | select(.name|match("credhub-linux-amd64.*\\.tgz$")) | .browser_download_url')

  if [[ -n "$download_url" ]]; then
    wget "$download_url" -O /tmp/credhub.tar.gz
    cd /tmp
    sudo tar -xzf /tmp/credhub.tar.gz
    sudo rm -f /tmp/credhub.tar.gz
    sudo mv /tmp/credhub /usr/bin
    echo "✓ Credhub CLI installed"
  else
    echo "⚠️  Could not find credhub download URL, skipping"
  fi
}

setupYqCli () {
  echo "Installing yq CLI..."
  local download_url
  download_url=$(curl -s https://api.github.com/repos/mikefarah/yq/releases/latest | jq -r '.assets[] | select(.name|match("linux_amd64$")) | .browser_download_url')

  if [[ -n "$download_url" ]]; then
    sudo wget "$download_url" -O /usr/bin/yq
    sudo chmod +x /usr/bin/yq
    echo "✓ yq CLI installed"
  else
    echo "⚠️  Could not find yq download URL, skipping"
  fi
}

# Setup bashrc
cat > ~/.bashrc << 'EOF'
export COMPOSE_DOCKER_CLI_BUILD=1
export DOCKER_BUILDKIT=1

# Initialize rvm (from base image)
source /usr/local/rvm/scripts/rvm

eval "$(direnv hook bash)"

# CF CLI helper - targets local nginx proxy
alias cflogin='cf api http://nginx --skip-ssl-validation && cf auth ccadmin secret'
EOF

echo "=== Setting up devcontainer ==="
echo "Using Ruby: $(ruby --version)"

setupAptPackages
setupCfCli
setupRubyGems
setupCredhubCli || true
setupYqCli || true

echo "=== Devcontainer setup complete ==="
