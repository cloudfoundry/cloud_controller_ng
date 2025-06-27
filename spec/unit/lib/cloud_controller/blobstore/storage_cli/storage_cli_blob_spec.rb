require 'spec_helper'
require_relative '../blob_shared'

module CloudController
  module Blobstore
    RSpec.describe StorageCliBlob do
      let(:properties) { { 'etag' => 'test-blob-etag', 'last_modified' => '2024-10-01T00:00:00Z', 'content_length' => 1024 } }
      let(:signed_url) { 'http://signed.example.com/test-blob' }

      subject(:blob) { StorageCliBlob.new('test-blob', properties:, signed_url:) }

      it_behaves_like 'a blob'

      describe '#key' do
        it 'returns the key of the blob' do
          expect(blob.key).to eq('test-blob')
        end
      end

      describe 'download_urls' do
        it 'returns the internal download URL of the blob' do
          expect(blob.internal_download_url).to eq(signed_url)
        end

        it 'returns the public download URL of the blob' do
          expect(blob.public_download_url).to eq(signed_url)
        end

        context 'when signed_url is not provided' do
          subject(:blob_without_signed_url) { StorageCliBlob.new('test-blob', properties:) }

          it 'raises an error when accessing internal_download_url' do
            expect { blob_without_signed_url.internal_download_url }.to raise_error(BlobstoreError, 'StorageCliBlob not configured with a signed URL')
          end

          it 'raises an error when accessing public_download_url' do
            expect { blob_without_signed_url.public_download_url }.to raise_error(BlobstoreError, 'StorageCliBlob not configured with a signed URL')
          end
        end
      end

      describe '#attributes' do
        it 'returns a hash of attributes for the blob' do
          expect(blob.attributes).to eq(
            etag: 'test-blob-etag',
            last_modified: '2024-10-01T00:00:00Z',
            created_at: nil,
            content_length: 1024
          )
        end

        it 'returns specific attributes when requested' do
          expect(blob.attributes(:etag)).to eq(etag: 'test-blob-etag')
        end

        context 'when properties are not provided' do
          subject(:blob_without_properties) { StorageCliBlob.new('test-blob', signed_url:) }

          it 'returns an empty hash for attributes' do
            expect(blob_without_properties.attributes).to eq({
                                                               etag: nil,
                                                               last_modified: nil,
                                                               created_at: nil,
                                                               content_length: nil
                                                             })
          end

          it 'returns nil for specific attributes' do
            expect(blob_without_properties.attributes(:etag, :last_modified, :created_at, :content_length)).to eq(
              etag: nil,
              last_modified: nil,
              created_at: nil,
              content_length: nil
            )
          end
        end
      end
    end
  end
end
