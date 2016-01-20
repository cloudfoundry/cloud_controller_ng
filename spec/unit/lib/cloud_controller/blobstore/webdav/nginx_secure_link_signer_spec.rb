require 'spec_helper'
require 'cloud_controller/blobstore/webdav/nginx_secure_link_signer'

module CloudController
  module Blobstore
    describe NginxSecureLinkSigner do
      subject(:signer) do
        described_class.new(
          secret:               secret,
          internal_host:        internal_host,
          internal_path_prefix: internal_path_prefix,
          public_host:          public_host,
          public_path_prefix:   public_path_prefix
        )
      end

      let(:secret) { 'some-secret' }

      let(:internal_host) { 'http://internal.example.com' }
      let(:internal_path_prefix) { nil }

      let(:public_host) { 'https://public.example.com' }
      let(:public_path_prefix) { nil }

      let(:expires) { 16726859876 } # some time in the year 2500

      describe '#sign_internal_url' do
        it 'signs the url with the internal host' do
          signed_url = signer.sign_internal_url(expires: expires, path: '/some/path')
          expect(signed_url).to eq('http://internal.example.com/some/path?expires=16726859876&md5=xSItWNqj4f9yoP8ZHFPgnw')
        end

        context 'when internal_path_prefix is configured' do
          let(:internal_path_prefix) { '/read/directory' }

          it 'signs the url with the path prefix' do
            signed_url = signer.sign_internal_url(expires: expires, path: '/some/path')
            expect(signed_url).to eq('http://internal.example.com/read/directory/some/path?expires=16726859876&md5=4bqEMqjriNxgNVZH8NRtRg')
          end
        end
      end

      describe '#sign_public_url' do
        it 'signs the url with the public host' do
          signed_url = signer.sign_public_url(expires: expires, path: '/some/path')
          expect(signed_url).to eq('https://public.example.com/some/path?expires=16726859876&md5=xSItWNqj4f9yoP8ZHFPgnw')
        end

        context 'when public_path_prefix is configured' do
          let(:public_path_prefix) { '/read/directory' }

          it 'signs the url with the path prefix' do
            signed_url = signer.sign_public_url(expires: expires, path: '/some/path')
            expect(signed_url).to eq('https://public.example.com/read/directory/some/path?expires=16726859876&md5=4bqEMqjriNxgNVZH8NRtRg')
          end
        end

        context 'when the public host does not have https scheme' do
          let(:public_host) { 'http://public.example.com' }

          it 'signs the url with an https scheme' do
            signed_url = signer.sign_public_url(expires: expires, path: '/some/path')
            expect(signed_url).to eq('https://public.example.com/some/path?expires=16726859876&md5=xSItWNqj4f9yoP8ZHFPgnw')
          end
        end
      end
    end
  end
end
