ARG RUBY_VERSION=3.3
FROM mcr.microsoft.com/vscode/devcontainers/ruby:${RUBY_VERSION}

# Docker CLI and compose are installed by the docker-outside-of-docker feature
COPY .devcontainer/images/devcontainer/setup.sh /tmp/setup.sh
USER vscode
RUN /tmp/setup.sh && sudo rm /tmp/setup.sh && sudo chmod 1777 /tmp

WORKDIR /workspace
