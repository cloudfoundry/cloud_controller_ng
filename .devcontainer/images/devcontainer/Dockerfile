FROM mcr.microsoft.com/vscode/devcontainers/ruby:3.2

COPY --from=docker:dind /usr/local/bin/docker /usr/local/bin/
COPY .devcontainer/images/devcontainer/setup.sh /tmp/setup.sh
COPY .ruby-version /tmp/.ruby-version
USER vscode
RUN /tmp/setup.sh && sudo rm /tmp/setup.sh /tmp/.ruby-version
