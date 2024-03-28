FROM golang:1

RUN CG_ENABLED=0 go install code.cloudfoundry.org/locket/cmd/locket@latest
RUN CG_ENABLED=0 go install code.cloudfoundry.org/bbs/cmd/bbs@latest
VOLUME /bbs

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT "/entrypoint.sh"
