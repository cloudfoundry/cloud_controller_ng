FROM golang:1

RUN apt update && apt install -y jq && git clone --recurse-submodules -b $(curl -s https://api.github.com/repos/cloudfoundry/diego-release/releases/latest | jq -r '.tag_name') https://github.com/cloudfoundry/diego-release && cd ./diego-release/src/code.cloudfoundry.org && \
    CG_ENABLED=0 go install code.cloudfoundry.org/locket/cmd/locket && \
    CG_ENABLED=0 go install code.cloudfoundry.org/bbs/cmd/bbs
VOLUME /bbs

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT "/entrypoint.sh"
