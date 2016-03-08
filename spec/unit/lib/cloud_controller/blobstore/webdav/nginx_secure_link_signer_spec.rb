require 'spec_helper'
require 'cloud_controller/blobstore/webdav/nginx_secure_link_signer'

module CloudController
  module Blobstore
    describe NginxSecureLinkSigner do
      subject(:signer) do
        described_class.new(
          internal_endpoint:    internal_endpoint,
          internal_path_prefix: internal_path_prefix,
          public_endpoint:      public_endpoint,
          public_path_prefix:   public_path_prefix,
          basic_auth_user:      user,
          basic_auth_password:  password
        )
      end

      let(:ssl_config) { double(:ssl_config, :verify_mode= => nil, set_default_paths: nil) }
      let(:httpclient) { instance_double(HTTPClient, ssl_config: ssl_config) }

      let(:expires) { 16726859876 } # some time in the year 2500

      let(:internal_endpoint) { 'http://internal.example.com' }
      let(:internal_path_prefix) { nil }

      let(:public_endpoint) { 'https://public.example.com' }
      let(:public_path_prefix) { nil }

      let(:user) { 'some-user' }
      let(:password) { 'some-password' }
      let(:basic_auth_header) { { 'Authorization' => 'Basic ' + Base64.strict_encode64("#{user}:#{password}").strip } }

      before do
        allow(HTTPClient).to receive_messages(new: httpclient)
      end

      describe 'ssl cert verification' do
        let(:skip_cert_verify) { true }
        let(:config) { { skip_cert_verify: skip_cert_verify } }

        before do
          allow(VCAP::CloudController::Config).to receive(:config).and_return(config)
          allow(signer).to receive(:new)
        end

        context 'when skip_cert_verify is set to true' do
          it 'verifies without certs' do
            expect(httpclient).to have_received(:ssl_config).exactly(2).times
            expect(ssl_config).to have_received(:verify_mode=).with(OpenSSL::SSL::VERIFY_NONE)
          end
        end

        context 'when skip_cert_verify is set to false' do
          let(:skip_cert_verify) { false }
          it 'verifies with certs' do
            expect(httpclient).to have_received(:ssl_config).exactly(2).times
            expect(ssl_config).to have_received(:verify_mode=).with(OpenSSL::SSL::VERIFY_PEER)
          end
        end
      end

      describe '#sign_internal_url' do
        let(:response) { instance_double(HTTP::Message, content: 'https://signed.example.com?valid-signing=some-md5-stuff', status: 200) }

        before do
          allow(httpclient).to receive_messages(get: response)
        end

        it 'requests a signed url from the blobstore with expires and path params' do
          signer.sign_internal_url(expires: expires, path: 'some/path')

          expected_request_uri = 'http://internal.example.com/sign?expires=16726859876&path=%2Fsome%2Fpath'
          expect(httpclient).to have_received(:get).with(expected_request_uri, header: basic_auth_header)
        end

        it 'returns the signed url from the response with the internal endpoint host as the signed uri host' do
          signed_url = signer.sign_internal_url(expires: expires, path: 'some/path')
          expect(signed_url).to eq('https://internal.example.com?valid-signing=some-md5-stuff')
        end

        context 'when internal_path_prefix is configured' do
          let(:internal_path_prefix) { '/read/directory' }

          it 'prepends it to the path in the signing request' do
            signer.sign_internal_url(expires: expires, path: 'some/path')

            expected_request_uri = 'http://internal.example.com/sign?expires=16726859876&path=%2Fread%2Fdirectory%2Fsome%2Fpath'
            expect(httpclient).to have_received(:get).with(expected_request_uri, header: basic_auth_header)
          end
        end

        context 'when the request returns an error' do
          let(:response) { instance_double(HTTP::Message, status: 401, content: '') }

          it 'raises an error' do
            expect {
              signer.sign_internal_url(expires: expires, path: 'some/path')
            }.to raise_error(SigningRequestError, /Could not get a signed url/)
          end
        end
      end

      describe '#sign_public_url' do
        let(:response) { instance_double(HTTP::Message, content: 'https://signed.example.com?valid-signing=some-md5-stuff', status: 200) }

        before do
          allow(httpclient).to receive_messages(get: response)
        end

        it 'requests a signed url from the blobstore with expires and path params' do
          signer.sign_public_url(expires: expires, path: 'some/path')

          expected_request_uri = 'http://internal.example.com/sign?expires=16726859876&path=%2Fsome%2Fpath'
          expect(httpclient).to have_received(:get).with(expected_request_uri, header: basic_auth_header)
        end

        it 'returns the signed url from the response with the public endpoint host as the signed uri host' do
          signed_url = signer.sign_public_url(expires: expires, path: 'some/path')
          expect(signed_url).to eq('https://public.example.com?valid-signing=some-md5-stuff')
        end

        context 'when public_path_prefix is configured' do
          let(:public_path_prefix) { '/read/directory' }

          it 'prepends it to the path in the signing request' do
            signer.sign_public_url(expires: expires, path: 'some/path')

            expected_request_uri = 'http://internal.example.com/sign?expires=16726859876&path=%2Fread%2Fdirectory%2Fsome%2Fpath'
            expect(httpclient).to have_received(:get).with(expected_request_uri, header: basic_auth_header)
          end
        end

        context 'when the public endpoint does not have https scheme' do
          let(:public_endpoint) { 'http://blobstore.example.com' }

          it 'signs the url with an https scheme' do
            signed_url = signer.sign_public_url(expires: expires, path: 'some/path')
            expect(signed_url).to eq('https://blobstore.example.com?valid-signing=some-md5-stuff')
          end
        end

        context 'when the request returns an error' do
          let(:response) { instance_double(HTTP::Message, status: 401, content: '') }

          it 'raises an error' do
            expect {
              signer.sign_public_url(expires: expires, path: 'some/path')
            }.to raise_error(SigningRequestError, /Could not get a signed url/)
          end
        end
      end
    end
  end
end
