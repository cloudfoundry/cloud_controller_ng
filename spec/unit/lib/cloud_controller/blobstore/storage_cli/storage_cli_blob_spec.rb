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
        context 'with pre-generated signed URL (eager signing for non-DAV providers)' do
          it 'returns the internal download URL of the blob' do
            expect(blob.internal_download_url).to eq(signed_url)
          end

          it 'returns the public download URL of the blob' do
            expect(blob.public_download_url).to eq(signed_url)
          end
        end

        context 'with lazy signing (for DAV provider)' do
          let(:storage_cli_client) { double('StorageCliClient') }

          before do
            allow(storage_cli_client).to receive(:supports_lazy_signing?).and_return(true)
          end

          subject(:lazy_blob) do
            StorageCliBlob.new(
              'dr/op/droplet-guid',
              properties: properties,
              storage_cli_client: storage_cli_client,
              expires_in_seconds: 3600
            )
          end

          describe '#internal_download_url' do
            it 'calls sign_internal_url on the storage_cli_client' do
              expect(storage_cli_client).to receive(:sign_internal_url).with(
                'dr/op/droplet-guid',
                verb: 'get',
                expires_in_seconds: 3600
              ).and_return('https://blobstore.internal:4443/read/cc-droplets/dr/op/droplet-guid?md5=internal123&expires=789')

              url = lazy_blob.internal_download_url

              expect(url).to eq('https://blobstore.internal:4443/read/cc-droplets/dr/op/droplet-guid?md5=internal123&expires=789')
            end

            it 'generates URL on-demand each time it is called' do
              call_count = 0
              allow(storage_cli_client).to receive(:sign_internal_url) do
                call_count += 1
                "https://blobstore.internal/url-#{call_count}"
              end

              url1 = lazy_blob.internal_download_url
              url2 = lazy_blob.internal_download_url

              expect(url1).to eq('https://blobstore.internal/url-1')
              expect(url2).to eq('https://blobstore.internal/url-2')
              expect(call_count).to eq(2)
            end
          end

          describe '#public_download_url' do
            it 'calls sign_public_url on the storage_cli_client' do
              expect(storage_cli_client).to receive(:sign_public_url).with(
                'dr/op/droplet-guid',
                verb: 'get',
                expires_in_seconds: 3600
              ).and_return('https://blobstore.example.com/read/cc-droplets/dr/op/droplet-guid?md5=public456&expires=999')

              url = lazy_blob.public_download_url

              expect(url).to eq('https://blobstore.example.com/read/cc-droplets/dr/op/droplet-guid?md5=public456&expires=999')
            end

            it 'generates URL on-demand each time it is called' do
              call_count = 0
              allow(storage_cli_client).to receive(:sign_public_url) do
                call_count += 1
                "https://blobstore.public/url-#{call_count}"
              end

              url1 = lazy_blob.public_download_url
              url2 = lazy_blob.public_download_url

              expect(url1).to eq('https://blobstore.public/url-1')
              expect(url2).to eq('https://blobstore.public/url-2')
              expect(call_count).to eq(2)
            end
          end

          it 'uses custom expires_in_seconds when provided' do
            custom_blob = StorageCliBlob.new(
              'test-key',
              properties: properties,
              storage_cli_client: storage_cli_client,
              expires_in_seconds: 7200
            )

            expect(storage_cli_client).to receive(:sign_internal_url).with(
              'test-key',
              verb: 'get',
              expires_in_seconds: 7200
            ).and_return('url')

            custom_blob.internal_download_url
          end
        end

        context 'when storage_cli_client does not support lazy signing' do
          let(:storage_cli_client) { double('StorageCliClient') }

          before do
            allow(storage_cli_client).to receive(:supports_lazy_signing?).and_return(false)
          end

          subject(:non_lazy_blob) do
            StorageCliBlob.new(
              'test-blob',
              properties: properties,
              signed_url: signed_url,
              storage_cli_client: storage_cli_client
            )
          end

          it 'falls back to using pre-generated signed_url for internal_download_url' do
            expect(non_lazy_blob.internal_download_url).to eq(signed_url)
          end

          it 'falls back to using pre-generated signed_url for public_download_url' do
            expect(non_lazy_blob.public_download_url).to eq(signed_url)
          end
        end

        context 'when signed_url is not provided and no storage_cli_client' do
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
