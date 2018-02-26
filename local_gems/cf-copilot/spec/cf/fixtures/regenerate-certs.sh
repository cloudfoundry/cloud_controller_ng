#!/bin/bash

set -euxo pipefail


clean ()
{
  rm -f *.key *.crt *.csr *.crl
}

make_certs () 
{ 
    ca_common_name="fakeCA"
    depot_path="."
    certstrap --depot-path ${depot_path} init --passphrase '' --common-name "${ca_common_name}"

    certstrap --depot-path ${depot_path} request-cert --passphrase '' --ip '127.0.0.1' --common-name "copilot-server";
    certstrap --depot-path ${depot_path} sign --passphrase '' --CA "${ca_common_name}" "copilot-server"

    certstrap --depot-path ${depot_path} request-cert --passphrase '' --ip '127.0.0.1' --common-name "cloud-controller-client"
    certstrap --depot-path ${depot_path} sign --passphrase '' --CA "${ca_common_name}" "cloud-controller-client"

    rm -f fakeCA.key fakeCA.crl *.csr
    chmod 644 *.crt *.key
}

cd "$(dirname "$0")"
clean
make_certs
