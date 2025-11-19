package main

import (
	"context"
	"crypto/tls"
	"crypto/x509"
	"log"
	"net"
	"os"

	"code.cloudfoundry.org/diego-logging-client/testhelpers"
	"code.cloudfoundry.org/go-loggregator/v9/rpc/loggregator_v2"
	"google.golang.org/grpc"
	"google.golang.org/grpc/credentials"
)

const port = ":3456"

func main() {
	certFile := os.Getenv("METRON_CERT")
	keyFile := os.Getenv("METRON_KEY")
	caFile := os.Getenv("METRON_CA")

	if certFile == "" || keyFile == "" || caFile == "" {
		log.Fatal("METRON_CERT, METRON_KEY, and METRON_CA environment variables must be set")
	}

	cert, err := tls.LoadX509KeyPair(certFile, keyFile)
	if err != nil {
		log.Fatalf("Failed to load server certificate: %v", err)
	}

	caCertBytes, err := os.ReadFile(caFile)
	if err != nil {
		log.Fatalf("Failed to read CA certificate: %v", err)
	}
	caCertPool := x509.NewCertPool()
	caCertPool.AppendCertsFromPEM(caCertBytes)

	tlsConfig := &tls.Config{
		Certificates:       []tls.Certificate{cert},
		ClientAuth:         tls.RequestClientCert,
		InsecureSkipVerify: false,
		RootCAs:            caCertPool,
		ClientCAs:          caCertPool,
	}

	lis, err := net.Listen("tcp4", port)
	if err != nil {
		log.Fatalf("Failed to listen on port %s: %v", port, err)
	}

	grpcServer := grpc.NewServer(grpc.Creds(credentials.NewTLS(tlsConfig)))

	fakeServer := &testhelpers.FakeIngressServer{}
	fakeServer.BatchSenderStub = func(srv loggregator_v2.Ingress_BatchSenderServer) error {
		<-srv.Context().Done()
		return nil
	}

	fakeServer.SendStub = func(ctx context.Context, batch *loggregator_v2.EnvelopeBatch) (*loggregator_v2.SendResponse, error) {
		return &loggregator_v2.SendResponse{}, nil
	}

	loggregator_v2.RegisterIngressServer(grpcServer, fakeServer)

	log.Printf("server listening on %s", port)
	if err := grpcServer.Serve(lis); err != nil {
		log.Fatalf("Failed to serve: %v", err)
	}
}

