FROM mcr.microsoft.com/devcontainers/base:ubuntu-24.04


SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Set environment variables for Ruby development
ENV BUNDLE_PATH=/home/vscode/.bundle
ENV GEM_HOME=/home/vscode/.gem
ENV GEM_PATH=/home/vscode/.gem
ENV RAILS_ENV=development
ENV RACK_ENV=development

# Install system dependencies for Ruby development
RUN wget -q -O - https://packages.cloudfoundry.org/debian/cli.cloudfoundry.org.key | gpg --dearmor -o /usr/share/keyrings/cli.cloudfoundry.org.gpg && \
    echo "deb [signed-by=/usr/share/keyrings/cli.cloudfoundry.org.gpg] https://packages.cloudfoundry.org/debian stable main" > /etc/apt/sources.list.d/cloudfoundry-cli.list && \
    apt-get update && \
    apt-get install -y \
    # CF CLI
    cf8-cli \
    # Build tools
    build-essential \
    autoconf \
    bison \
    patch \
    # Ruby dependencies
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    libncurses5-dev \
    libffi-dev \
    libgdbm-dev \
    libyaml-dev \
    libsqlite3-dev \
    sqlite3 \
    libgmp-dev \
    libgdbm6 \
    libdb-dev \
    uuid-dev \
    # Database clients
    postgresql-client \
    postgresql-client-common \
    mysql-client \
    redis-tools \
    # Database development headers
    libpq-dev \
    default-libmysqlclient-dev \
    # Development tools
    curl \
    wget \
    git \
    vim \
    nano \
    htop \
    tree \
    jq \
    unzip \
    zip \
    # Network tools
    netcat-openbsd \
    # XML/HTML processing
    libxml2-dev \
    libxslt1-dev \
    # GPG for RVM
    gnupg2 \
    # Additional utilities
    tmux \
    screen \
    less \
    man-db \
    && rm -rf /var/lib/apt/lists/*

# Install yq v4 for the correct architecture
RUN YQ_ARCH=$(uname -m) && \
    case $YQ_ARCH in \
    x86_64) YQ_ARCH="amd64";; \
    aarch64) YQ_ARCH="arm64";; \
    esac && \
    wget "https://github.com/mikefarah/yq/releases/download/v4.47.1/yq_linux_${YQ_ARCH}" -O /usr/local/bin/yq && \
    chmod +x /usr/local/bin/yq


USER vscode

# Create necessary directories and set permissions
RUN mkdir -p $BUNDLE_PATH $GEM_HOME && chown -R vscode:vscode $BUNDLE_PATH $GEM_HOME

# Install GPG keys for RVM
RUN gpg2 --keyserver keyserver.ubuntu.com --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3 7D2BAF1CF37B13E2069D6956105BD0E739499BDB

# Install RVM
RUN curl -sSL https://get.rvm.io | bash -s stable --path /home/vscode/.rvm

# Copy Ruby version file for reference
COPY .ruby-version /tmp/ruby-version

# Install Ruby using RVM with binary packages when available, fallback to parallel source compilation
RUN /bin/bash -l -c "source /home/vscode/.rvm/scripts/rvm && \
    export rvm_make_opts=\"-j$(nproc)\" && \
    export RUBY_CONFIGURE_OPTS=\"--disable-install-doc\" && \
    rvm install $(cat /tmp/ruby-version) && \
    rvm use $(cat /tmp/ruby-version) --default && \
    gem install bundler"

# Configure Bundler and install cf-uaac as vscode user
RUN /bin/bash -l -c "source /home/vscode/.rvm/scripts/rvm && \
    bundle config set --global path \"$BUNDLE_PATH\" && \
    bundle config set --global jobs $(nproc) && \
    bundle config set --global specific_platform true && \
    gem install cf-uaac"

# Configure Git
RUN git config --global core.fileMode false

# Source RVM and configure shell
RUN echo 'export BUNDLE_PATH="$BUNDLE_PATH"' >> /home/vscode/.bashrc \
    && echo 'export GEM_HOME="$GEM_HOME"' >> /home/vscode/.bashrc \
    && echo 'export GEM_PATH="$GEM_PATH"' >> /home/vscode/.bashrc \
    && echo 'source /home/vscode/.rvm/scripts/rvm' >> /home/vscode/.bashrc 

# Configure Git (useful defaults)
RUN git config --global init.defaultBranch main \
    && git config --global pull.rebase false \
    && git config --global core.autocrlf input

# Set working directory
WORKDIR /workspace
USER root
# Sleep forever to keep the container running
CMD ["tail", "-f", "/dev/null"]
