require 'spec_helper'
require 'cloud_controller/blobstore/retryable_blob'
require 'cloud_controller/blobstore/null_blob'
require_relative 'blob_shared'

module CloudController
  module Blobstore
    RSpec.describe RetryableBlob do
      subject(:blob) do
        described_class.new(
          blob: wrapped_blob,
          errors: [RetryableError],
          logger: logger,
          num_retries: num_retries
        )
      end

      let(:wrapped_blob) { NullBlob.new }
      let(:logger) { instance_double(Steno::Logger, debug: nil) }
      let(:log_prefix) { 'cc.retryable' }
      let(:log_data) { { some: 'error' } }
      let(:num_retries) { 3 }

      class RetryableError < StandardError
      end

      describe 'conforms to blob interface' do
        it_behaves_like 'a blob'
      end

      describe 'retries' do
        context '#internal_download_url' do
          before { allow(wrapped_blob).to receive(:internal_download_url).and_raise(RetryableError) }

          it 'retries the operation' do
            expect {
              blob.internal_download_url
            }.to raise_error RetryableError

            expect(wrapped_blob).to have_received(:internal_download_url).exactly(num_retries).times
          end
        end

        context '#public_download_url' do
          before { allow(wrapped_blob).to receive(:public_download_url).and_raise(RetryableError) }

          it 'retries the operation' do
            expect {
              blob.public_download_url
            }.to raise_error RetryableError

            expect(wrapped_blob).to have_received(:public_download_url).exactly(num_retries).times
          end
        end

        context '#attributes' do
          before { allow(wrapped_blob).to receive(:attributes).and_raise(RetryableError) }
          let(:keys)  { { 'ETag' => 'the-etag', 'Last-Modified' => 'modified-date', 'Content-Length' => 123455 } }

          it 'retries the operation' do
            expect {
              blob.attributes(keys)
            }.to raise_error RetryableError

            expect(wrapped_blob).to have_received(:attributes).with(keys).exactly(num_retries).times
          end
        end

        context '#local_path' do
          before { allow(wrapped_blob).to receive(:local_path).and_raise(RetryableError) }

          it 'retries the operation' do
            expect {
              blob.local_path
            }.to raise_error RetryableError

            expect(wrapped_blob).to have_received(:local_path).exactly(num_retries).times
          end
        end
      end

      describe '#with_retries' do
        it 'retries if the operation fails' do
          operation = double(:operation)
          called    = 0
          allow(operation).to receive(:call) do |_|
            called += 1
            raise RetryableError.new if called == 1
            true
          end

          blob.send(:with_retries, log_prefix, log_data) { operation.call }

          expect(operation).to have_received(:call).exactly(:twice)
        end

        it 'returns the result of the operation after retries' do
          operation = double(:operation)
          called    = 0
          allow(operation).to receive(:call) do |_|
            called += 1
            raise RetryableError.new if called == 1
            'potato'
          end

          result = blob.send(:with_retries, log_prefix, log_data) { operation.call }

          expect(result).to eq('potato')
        end

        it 'raises the operation error if all retries fail' do
          operation = double(:operation)
          allow(operation).to receive(:call).and_raise(RetryableError.new)

          expect {
            blob.send(:with_retries, log_prefix, log_data) { operation.call }
          }.to raise_error(RetryableError)

          expect(operation).to have_received(:call).exactly(num_retries).times
        end

        it 'logs the operation on retry' do
          operation = double(:operation)
          allow(operation).to receive(:call).and_raise(RetryableError.new)

          expect {
            blob.send(:with_retries, log_prefix, log_data) { operation.call }
          }.to raise_error RetryableError

          expect(logger).to have_received(:debug).exactly(num_retries).times
        end
      end
    end
  end
end
