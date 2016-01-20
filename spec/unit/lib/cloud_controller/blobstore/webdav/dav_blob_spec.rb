require 'spec_helper'
require_relative '../blob_shared'

module CloudController
  module Blobstore
    describe DavBlob do
      subject(:blob) { DavBlob.new(httpmessage: httpmessage, key: 'fo/ob/foobar', signer: signer) }
      let(:httpmessage) { instance_double(HTTP::Message, headers: {}) }
      let(:key) { 'fo/ob/foobar' }
      let(:signer) do
        NginxSecureLinkSigner.new(
          secret:               'some-secret',
          internal_host:        'http://blobstore.private.com',
          internal_path_prefix: '/read',
          public_host:          'https://blobstore.public.com',
          public_path_prefix:   '/read'
        )
      end

      it_behaves_like 'a blob'

      describe 'attributes' do
        let(:headers) { { 'ETag' => 'the-etag', 'Last-Modified' => 'modified-date', 'Content-Length' => 123455 } }

        before do
          allow(httpmessage).to receive(:headers).and_return(headers)
        end

        it "returns the blob's attributes" do
          expect(blob.attributes).to eq(
            {
              etag:          'the-etag',
              last_modified: 'modified-date',
              content_length: 123455,
              created_at:    nil,
            }
          )
        end

        it 'returns attributes for a set of keys' do
          expect(blob.attributes(:etag)).to eq({ etag: 'the-etag' })
        end
      end

      describe 'internal_download_url' do
        it 'generates a signed expiring url with expiration of 1 hour' do
          # using nginx method defined here: http://nginx.org/en/docs/http/ngx_http_secure_link_module.html

          Timecop.freeze(Time.utc(2008, 1, 1, 12, 0, 0)) do
            expect(blob.internal_download_url).to eq('http://blobstore.private.com/read/fo/ob/foobar?expires=1199192400&md5=3RBuMi1CauNAw8thvmZfPw')
          end
        end
      end

      describe 'public_download_url' do
        it 'generates a signed expiring url with expiration of 1 hour' do
          # using nginx method defined here: http://nginx.org/en/docs/http/ngx_http_secure_link_module.html

          Timecop.freeze(Time.utc(2008, 1, 1, 12, 0, 0)) do
            expect(blob.public_download_url).to eq('https://blobstore.public.com/read/fo/ob/foobar?expires=1199192400&md5=3RBuMi1CauNAw8thvmZfPw')
          end
        end
      end
    end
  end
end
