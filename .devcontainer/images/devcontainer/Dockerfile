FROM mcr.microsoft.com/vscode/devcontainers/ruby:3.1

COPY --from=docker:dind /usr/local/bin/docker /usr/local/bin/
COPY setup.sh /tmp/setup.sh
USER vscode
RUN /tmp/setup.sh && sudo rm /tmp/setup.sh