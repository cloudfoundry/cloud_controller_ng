FROM golang:1

RUN apt update && git clone --recurse-submodules -b v2.118.0 https://github.com/cloudfoundry/diego-release && cd ./diego-release/src/code.cloudfoundry.org && \
    CG_ENABLED=0 go install code.cloudfoundry.org/locket/cmd/locket && \
    CG_ENABLED=0 go install code.cloudfoundry.org/bbs/cmd/bbs
VOLUME /bbs

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT "/entrypoint.sh"
