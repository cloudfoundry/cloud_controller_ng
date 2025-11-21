FROM golang:1

WORKDIR /app

COPY main.go .
COPY go.* .

RUN go build -o metron main.go

CMD ["/app/metron"]
