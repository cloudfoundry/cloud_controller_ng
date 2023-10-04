require 'spec_helper'
require 'cloud_controller/blobstore/retryable_client'
require 'cloud_controller/blobstore/null_client'
require_relative 'client_shared'

module CloudController
  module Blobstore
    RSpec.describe RetryableClient do
      subject(:client) do
        RetryableClient.new(
          client: wrapped_client,
          errors: [RetryableError],
          logger: logger,
          num_retries: num_retries
        )
      end

      let(:wrapped_client) { NullClient.new }
      let(:logger) { instance_double(Steno::Logger, debug: nil) }
      let(:log_prefix) { 'cc.retryable' }
      let(:log_data) { { some: 'error' } }
      let(:num_retries) { 4 }

      class RetryableError < StandardError
      end

      describe 'conforms to blobstore client interface' do
        let(:deletable_blob) { instance_double(DavBlob, key: nil) }

        it_behaves_like 'a blobstore client'
      end

      describe '#blob' do
        it 'wraps the blob from the client in a RetryableBlob' do
          wrapped_blob = instance_double(Blob)
          allow(wrapped_client).to receive(:blob).and_return(wrapped_blob)

          blob = client.blob('my-key')
          expect(blob).to be_a(RetryableBlob)
          expect(blob.num_retries).to eq(num_retries)
          expect(blob.retryable_errors).to eq([RetryableError])
          expect(blob.wrapped_blob).to eq(wrapped_blob)
          expect(blob.logger).to eq(logger)
        end

        it 'returns nil if blob to wrap is nil' do
          wrapped_blob = nil
          allow(wrapped_client).to receive(:blob).and_return(wrapped_blob)

          expect(client.blob('my-key')).to be_nil
        end
      end

      describe 'retries' do
        let(:wrapped_client) { instance_double(NullClient) }

        describe '#exists?' do
          let(:key) { 'some-key' }

          before { allow(wrapped_client).to receive(:exists?).and_raise(RetryableError) }

          it 'retries the operation' do
            expect do
              client.exists?(key)
            end.to raise_error RetryableError

            expect(wrapped_client).to have_received(:exists?).with(key).exactly(num_retries).times
          end
        end

        describe '#download_from_blobstore' do
          let(:source_key) { 'some-key' }
          let(:destination_path) { 'some-path' }

          before { allow(wrapped_client).to receive(:download_from_blobstore).and_raise(RetryableError) }

          it 'retries the operation' do
            expect do
              client.download_from_blobstore(source_key, destination_path)
            end.to raise_error RetryableError

            expect(wrapped_client).to have_received(:download_from_blobstore).with(source_key, destination_path, mode: nil).exactly(num_retries).times
          end
        end

        describe '#cp_to_blobstore' do
          let(:source_path) { 'some-path' }
          let(:destination_key) { 'some-key' }

          before { allow(wrapped_client).to receive(:cp_to_blobstore).and_raise(RetryableError) }

          it 'retries the operation' do
            expect do
              client.cp_to_blobstore(source_path, destination_key)
            end.to raise_error RetryableError

            expect(wrapped_client).to have_received(:cp_to_blobstore).with(source_path, destination_key).exactly(num_retries).times
          end
        end

        describe '#cp_r_to_blobstore' do
          let(:source_dir) { 'some-dir' }

          before { allow(wrapped_client).to receive(:cp_r_to_blobstore).and_raise(RetryableError) }

          it 'retries the operation' do
            expect do
              client.cp_r_to_blobstore(source_dir)
            end.to raise_error RetryableError

            expect(wrapped_client).to have_received(:cp_r_to_blobstore).with(source_dir).exactly(num_retries).times
          end
        end

        describe '#cp_file_between_keys' do
          let(:source_key) { 'some-key' }
          let(:destination_key) { 'some-destination-key' }

          before { allow(wrapped_client).to receive(:cp_file_between_keys).and_raise(RetryableError) }

          it 'retries the operation' do
            expect do
              client.cp_file_between_keys(source_key, destination_key)
            end.to raise_error RetryableError

            expect(wrapped_client).to have_received(:cp_file_between_keys).with(source_key, destination_key).exactly(num_retries).times
          end
        end

        describe '#delete_all' do
          let(:page_size) { 123 }

          before { allow(wrapped_client).to receive(:delete_all).and_raise(RetryableError) }

          it 'retries the operation' do
            expect do
              client.delete_all(page_size)
            end.to raise_error RetryableError

            expect(wrapped_client).to have_received(:delete_all).with(page_size).exactly(num_retries).times
          end
        end

        describe '#delete_all_in_path' do
          let(:path) { 'some-path' }

          before { allow(wrapped_client).to receive(:delete_all_in_path).and_raise(RetryableError) }

          it 'retries the operation' do
            expect do
              client.delete_all_in_path(path)
            end.to raise_error RetryableError

            expect(wrapped_client).to have_received(:delete_all_in_path).with(path).exactly(num_retries).times
          end
        end

        describe '#delete' do
          let(:key) { 'some-key' }

          before { allow(wrapped_client).to receive(:delete).and_raise(RetryableError) }

          it 'retries the operation' do
            expect do
              client.delete(key)
            end.to raise_error RetryableError

            expect(wrapped_client).to have_received(:delete).with(key).exactly(num_retries).times
          end
        end

        describe '#delete_blob' do
          let(:blob) { 'some-blob' }

          before { allow(wrapped_client).to receive(:delete_blob).and_raise(RetryableError) }

          it 'retries the operation' do
            expect do
              client.delete_blob(blob)
            end.to raise_error RetryableError

            expect(wrapped_client).to have_received(:delete_blob).with(blob).exactly(num_retries).times
          end
        end

        describe '#blob' do
          let(:key) { 'some-blob' }

          before { allow(wrapped_client).to receive(:blob).and_raise(RetryableError) }

          it 'retries the operation' do
            expect do
              client.blob(key)
            end.to raise_error RetryableError

            expect(wrapped_client).to have_received(:blob).with(key).exactly(num_retries).times
          end
        end

        describe '#files_for' do
          let(:prefix) { 'pre' }
          let(:ignored_directory_prefixes) { ['no'] }

          before { allow(wrapped_client).to receive(:files_for).and_raise(RetryableError) }

          it 'retries the operation' do
            expect { client.files_for(prefix, ignored_directory_prefixes) }.to raise_error RetryableError

            expect(wrapped_client).to have_received(:files_for).with(prefix, ignored_directory_prefixes).exactly(num_retries).times
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

          client.send(:with_retries, log_prefix, log_data) { operation.call }

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

          result = client.send(:with_retries, log_prefix, log_data) { operation.call }

          expect(result).to eq('potato')
        end

        it 'raises the operation error if all retries fail' do
          operation = double(:operation)
          allow(operation).to receive(:call).and_raise(RetryableError.new)

          expect do
            client.send(:with_retries, log_prefix, log_data) { operation.call }
          end.to raise_error(RetryableError)

          expect(operation).to have_received(:call).exactly(num_retries).times
        end

        it 'logs the operation on retry' do
          operation = double(:operation)
          allow(operation).to receive(:call).and_raise(RetryableError.new)

          expect do
            client.send(:with_retries, log_prefix, log_data) { operation.call }
          end.to raise_error RetryableError

          expect(logger).to have_received(:debug).exactly(num_retries).times
        end
      end
    end
  end
end
