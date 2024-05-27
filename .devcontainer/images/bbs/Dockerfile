FROM golang:1

RUN CG_ENABLED=0 go install github.com/sap-contributions/locket/cmd/locket@latest
RUN CG_ENABLED=0 go install github.com/sap-contributions/bbs/cmd/bbs@latest
VOLUME /bbs

COPY entrypoint.sh /entrypoint.sh

ENTRYPOINT "/entrypoint.sh"
