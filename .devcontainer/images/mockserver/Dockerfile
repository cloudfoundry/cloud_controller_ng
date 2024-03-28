FROM golang:1

WORKDIR /mock

COPY main.go .
COPY go.* .

RUN go build -o mock main.go

CMD ["/mock/mock"]
