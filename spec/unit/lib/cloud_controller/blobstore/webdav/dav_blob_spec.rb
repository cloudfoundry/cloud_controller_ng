require 'spec_helper'
require_relative '../blob_shared'

module CloudController
  module Blobstore
    RSpec.describe DavBlob do
      subject(:blob) { DavBlob.new(httpmessage: httpmessage, key: 'fo/ob/foobar', signer: signer) }
      let(:httpmessage) { instance_double(HTTP::Message, headers: {}) }
      let(:key) { 'fo/ob/foobar' }
      let(:signer) { instance_double(NginxSecureLinkSigner) }

      describe 'being a blob' do
        before do
          allow(signer).to receive(:sign_public_url)
          allow(signer).to receive(:sign_internal_url)
        end

        it_behaves_like 'a blob'
      end

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
              created_at: nil,
            }
          )
        end

        it 'returns attributes for a set of keys' do
          expect(blob.attributes(:etag)).to eq({ etag: 'the-etag' })
        end
      end

      describe 'internal_download_url' do
        before do
          allow(signer).to receive(:sign_internal_url)
        end

        it 'requests a signed expiring url with expiration of 1 hour' do
          Timecop.freeze(Time.utc(2008, 1, 1, 12, 0, 0)) do
            blob.internal_download_url
            expect(signer).to have_received(:sign_internal_url).with(path: 'fo/ob/foobar', expires: 1199192400)
          end
        end
      end

      describe 'public_download_url' do
        before do
          allow(signer).to receive(:sign_public_url)
        end

        it 'generates a signed expiring url with expiration of 1 hour' do
          Timecop.freeze(Time.utc(2008, 1, 1, 12, 0, 0)) do
            blob.public_download_url
            expect(signer).to have_received(:sign_public_url).with(path: 'fo/ob/foobar', expires: 1199192400)
          end
        end
      end
    end
  end
end
