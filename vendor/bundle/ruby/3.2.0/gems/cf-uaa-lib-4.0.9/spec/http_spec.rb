#--
# Cloud Foundry 2012.02.03 Beta
# Copyright (c) [2009-2012] VMware, Inc. All Rights Reserved.
#
# This product is licensed to you under the Apache License, Version 2.0 (the "License").
# You may not use this product except in compliance with the License.
#
# This product includes a number of subcomponents with
# separate copyright notices and license terms. Your use of these
# subcomponents is subject to the terms and conditions of the
# subcomponent's license, as noted in the LICENSE file.
#++

require 'spec_helper'
require 'uaa/http'
require 'uaa/version'

describe CF::UAA::Http do

  class HttpTest
    include CF::UAA::Http

    public :http_get
  end

  let(:http_instance) { HttpTest.new }

  let(:http_double) do
    http_double = double('http').as_null_object
    expect(HTTPClient).to receive(:new).and_return(http_double)
    http_double
  end

  let(:cert_store) { double('OpenSSL::X509::Store') }

  describe 'set_request_handler' do
    it 'sets a request handler' do
      http_instance.set_request_handler do |url, method, body, headers|
        [200, 'body', {'content-type' => 'text/plain'}]
      end
      status, body, resp_headers = http_instance.http_get('http://example.com')
      status.should == 200
      body.should == 'body'
      resp_headers['content-type'].should == 'text/plain'
    end
  end

  describe 'http_get' do

    context 'when response has no status' do
      let(:response) { double('http::message') }
      it 'raises an HTTPException error' do
        expect(response).to receive(:status)
        expect(response).to receive(:content).and_return('TEST')
        expect(http_double).to receive(:get).and_return(response)
        expect { http_instance.http_get('https://example.com') }.to raise_error(CF::UAA::HTTPException, "Can't parse response from the server TEST")
      end
    end

    context 'when certificate is not valid' do
      it 'raises an SSLException' do
        expect(http_double).to receive(:get).and_raise(OpenSSL::SSL::SSLError)

        expect { http_instance.http_get('https://example.com') }.to raise_error(CF::UAA::SSLException)
      end
    end

    context 'when skipping ssl validation' do
      let(:ssl_config) { double('ssl_config') }

      it 'sets verify mode to VERIFY_NONE' do
        http_instance.initialize_http_options({skip_ssl_validation: true})

        expect(http_double).to receive(:ssl_config).and_return(ssl_config)
        expect(ssl_config).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
        http_instance.http_get('https://uncached.example.com')
      end
    end

    context 'when validating ssl' do
      let(:ssl_config) { double('ssl_config') }

      it 'sets default values' do
        expect(http_double).to receive(:ssl_config).and_return(ssl_config)
        expect(ssl_config).to receive(:set_default_paths)
        http_instance.http_get('https://example.com')
      end
    end

    context 'when ssl certificate is provided' do
      let(:ssl_config) { double('ssl_config') }

      it 'passes it' do
        http_instance.initialize_http_options({ssl_ca_file: '/fake-ca-file'})

        expect(http_double).to receive(:ssl_config).and_return(ssl_config).twice
        expect(ssl_config).to receive(:set_trust_ca).with('/fake-ca-file')
        expect(ssl_config).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)

        http_instance.http_get('https://uncached.example.com')
      end
    end

    context 'when ssl cert store is provided' do
      let(:ssl_config) { double('ssl_config') }

      it 'passes it' do
        http_instance.initialize_http_options({ssl_cert_store: cert_store})

        expect(http_double).to receive(:ssl_config).and_return(ssl_config).twice
        expect(ssl_config).to receive(:cert_store=).with(cert_store)
        expect(ssl_config).to receive(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)

        http_instance.http_get('https://uncached.example.com')
      end
    end

    context 'when an http request timeout is provided' do
      it 'sets all timeouts on the http clien to the http_timeout' do
        http_instance.initialize_http_options({http_timeout: 10})

        expect(http_double).to receive(:connect_timeout=).with(10)
        expect(http_double).to receive(:send_timeout=).with(10)
        expect(http_double).to receive(:receive_timeout=).with(10)

        http_instance.http_get('https://uncached.example.com')
      end
    end

    context 'when an http request timeout is not provided' do
      it 'does not override the default' do
        http_instance.initialize_http_options({})

        expect(http_double).not_to receive(:connect_timeout=)
        expect(http_double).not_to receive(:send_timeout=)
        expect(http_double).not_to receive(:receive_timeout=)

        http_instance.http_get('https://uncached.example.com')
      end
    end
  end
end
