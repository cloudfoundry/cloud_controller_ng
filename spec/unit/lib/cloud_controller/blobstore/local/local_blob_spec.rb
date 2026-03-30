require 'spec_helper'

module CloudController
  module Blobstore
    RSpec.describe LocalBlob do
      let(:key) { 'te/st/test-key' }
      let(:file_path) { Tempfile.new('local_blob_test').path }
      let(:file_content) { 'test content for blob' }

      subject(:blob) { LocalBlob.new(key: key, file_path: file_path) }

      before do
        File.write(file_path, file_content)
      end

      after do
        FileUtils.rm_f(file_path)
      end

      describe '#key' do
        it 'returns the key' do
          expect(blob.key).to eq('te/st/test-key')
        end
      end

      describe '#local_path' do
        it 'returns the file path' do
          expect(blob.local_path).to eq(file_path)
        end
      end

      describe '#internal_download_url' do
        it 'returns nil' do
          expect(blob.internal_download_url).to be_nil
        end
      end

      describe '#public_download_url' do
        it 'returns nil' do
          expect(blob.public_download_url).to be_nil
        end
      end

      describe '#attributes' do
        it 'returns all attributes when no keys specified' do
          attrs = blob.attributes
          expect(attrs).to include(:etag, :last_modified, :content_length, :created_at)
        end

        it 'returns the etag as MD5 hash of file content' do
          expected_etag = OpenSSL::Digest::MD5.hexdigest(file_content)
          expect(blob.attributes[:etag]).to eq(expected_etag)
        end

        it 'returns the content length as string' do
          expect(blob.attributes[:content_length]).to eq(file_content.length.to_s)
        end

        it 'returns last_modified in httpdate format' do
          expect(blob.attributes[:last_modified]).to match(/\w+, \d+ \w+ \d+ \d+:\d+:\d+ GMT/)
        end

        it 'returns created_at as a Time object' do
          expect(blob.attributes[:created_at]).to be_a(Time)
        end

        it 'returns only requested keys when specified' do
          attrs = blob.attributes(:etag, :content_length)
          expect(attrs.keys).to contain_exactly(:etag, :content_length)
        end

        it 'caches attributes' do
          first_call = blob.attributes
          second_call = blob.attributes
          expect(first_call).to be(second_call)
        end
      end
    end
  end
end
