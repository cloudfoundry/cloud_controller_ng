require 'spec_helper'
require 'cloud_controller/blobstore/retryable_client'
require 'cloud_controller/blobstore/null_client'
require_relative 'client_shared'

module CloudController
  module Blobstore
    RSpec.describe RetryableClient do
      subject(:client) do
        described_class.new(
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
      let(:num_retries) { 3 }

      class RetryableError < StandardError
      end

      describe 'conforms to blobstore client interface' do
        let(:deletable_blob) { instance_double(DavBlob, key: nil) }

        it_behaves_like 'a blobstore client'
      end

      describe 'retries' do
        let(:wrapped_client) { instance_double(NullClient) }

        context '#download_from_blobstore' do
          let(:source_key) { 'some-key' }
          let(:destination_path) { 'some-path' }

          before { allow(wrapped_client).to receive(:download_from_blobstore).and_raise(RetryableError) }

          it 'retries the operation' do
            expect {
              client.download_from_blobstore(source_key, destination_path)
            }.to raise_error RetryableError

            expect(wrapped_client).to have_received(:download_from_blobstore).with(source_key, destination_path, mode: nil).exactly(num_retries).times
          end
        end

        context '#cp_to_blobstore' do
          let(:source_path) { 'some-path' }
          let(:destination_key) { 'some-key' }

          before { allow(wrapped_client).to receive(:cp_to_blobstore).and_raise(RetryableError) }

          it 'retries the operation' do
            expect {
              client.cp_to_blobstore(source_path, destination_key)
            }.to raise_error RetryableError

            expect(wrapped_client).to have_received(:cp_to_blobstore).with(source_path, destination_key).exactly(num_retries).times
          end
        end

        context '#cp_r_to_blobstore' do
          let(:source_dir) { 'some-dir' }

          before { allow(wrapped_client).to receive(:cp_r_to_blobstore).and_raise(RetryableError) }

          it 'retries the operation' do
            expect {
              client.cp_r_to_blobstore(source_dir)
            }.to raise_error RetryableError

            expect(wrapped_client).to have_received(:cp_r_to_blobstore).with(source_dir).exactly(num_retries).times
          end
        end

        context '#cp_file_between_keys' do
          let(:source_key) { 'some-key' }
          let(:destination_key) { 'some-destination-key' }

          before { allow(wrapped_client).to receive(:cp_file_between_keys).and_raise(RetryableError) }

          it 'retries the operation' do
            expect {
              client.cp_file_between_keys(source_key, destination_key)
            }.to raise_error RetryableError

            expect(wrapped_client).to have_received(:cp_file_between_keys).with(source_key, destination_key).exactly(num_retries).times
          end
        end

        context '#delete_all' do
          let(:page_size) { 123 }

          before { allow(wrapped_client).to receive(:delete_all).and_raise(RetryableError) }

          it 'retries the operation' do
            expect {
              client.delete_all(page_size)
            }.to raise_error RetryableError

            expect(wrapped_client).to have_received(:delete_all).with(page_size).exactly(num_retries).times
          end
        end

        context '#delete_all_in_path' do
          let(:path) { 'some-path' }

          before { allow(wrapped_client).to receive(:delete_all_in_path).and_raise(RetryableError) }

          it 'retries the operation' do
            expect {
              client.delete_all_in_path(path)
            }.to raise_error RetryableError

            expect(wrapped_client).to have_received(:delete_all_in_path).with(path).exactly(num_retries).times
          end
        end

        context '#delete' do
          let(:key) { 'some-key' }

          before { allow(wrapped_client).to receive(:delete).and_raise(RetryableError) }

          it 'retries the operation' do
            expect {
              client.delete(key)
            }.to raise_error RetryableError

            expect(wrapped_client).to have_received(:delete).with(key).exactly(num_retries).times
          end
        end

        context '#delete_blob' do
          let(:blob) { 'some-blob' }

          before { allow(wrapped_client).to receive(:delete_blob).and_raise(RetryableError) }

          it 'retries the operation' do
            expect {
              client.delete_blob(blob)
            }.to raise_error RetryableError

            expect(wrapped_client).to have_received(:delete_blob).with(blob).exactly(num_retries).times
          end
        end

        context '#blob' do
          let(:key) { 'some-blob' }

          before { allow(wrapped_client).to receive(:blob).and_raise(RetryableError) }

          it 'retries the operation' do
            expect {
              client.blob(key)
            }.to raise_error RetryableError

            expect(wrapped_client).to have_received(:blob).with(key).exactly(num_retries).times
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

          expect {
            client.send(:with_retries, log_prefix, log_data) { operation.call }
          }.to raise_error(RetryableError)

          expect(operation).to have_received(:call).exactly(num_retries).times
        end

        it 'logs the operation on retry' do
          operation = double(:operation)
          allow(operation).to receive(:call).and_raise(RetryableError.new)

          expect {
            client.send(:with_retries, log_prefix, log_data) { operation.call }
          }.to raise_error RetryableError

          expect(logger).to have_received(:debug).exactly(num_retries).times
        end
      end
    end
  end
end
