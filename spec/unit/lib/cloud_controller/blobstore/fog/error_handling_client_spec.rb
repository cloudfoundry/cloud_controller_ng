require 'spec_helper'
require_relative '../client_shared'
require 'cloud_controller/blobstore/fog/error_handling_client'
require 'cloud_controller/blobstore/null_client'

module CloudController
  module Blobstore
    RSpec.describe ErrorHandlingClient do
      subject(:client) { ErrorHandlingClient.new(wrapped_client) }
      let(:wrapped_client) { Blobstore::NullClient.new }
      let(:logger) { instance_double(Steno::Logger, error: nil) }

      before do
        allow(Steno).to receive(:logger).and_return(logger)
      end

      describe 'conforms to blobstore client interface' do
        let(:deletable_blob) { nil }

        it_behaves_like 'a blobstore client'
      end

      describe '#delete_all' do
        before do
          allow(wrapped_client).to receive(:delete_all).and_raise(Excon::Errors::Error.new('error message'))
        end

        it 'handles errors and delegates to wrapped client' do
          expect do
            client.delete_all
          end.to raise_error(BlobstoreError, 'error message')
          expect(logger).to have_received(:error).with('Error with blobstore: Excon::Error - error message')
        end
      end

      describe '#delete_all_in_path' do
        before do
          allow(wrapped_client).to receive(:delete_all_in_path).and_raise(Excon::Errors::Error.new('error message'))
        end

        it 'handles errors and delegates to wrapped client' do
          expect do
            client.delete_all_in_path('sallow\\dossy\\path')
          end.to raise_error(BlobstoreError, 'error message')
          expect(logger).to have_received(:error).with('Error with blobstore: Excon::Error - error message')
        end
      end

      describe '#exists?' do
        before do
          allow(wrapped_client).to receive(:exists?).and_raise(Excon::Errors::Error.new('error message'))
        end

        it 'handles errors and delegates to wrapped client' do
          expect do
            client.exists?('off')
          end.to raise_error(BlobstoreError, 'error message')
          expect(logger).to have_received(:error).with('Error with blobstore: Excon::Error - error message')
        end
      end

      describe '#blob' do
        before do
          allow(wrapped_client).to receive(:blob).and_raise(Excon::Errors::Error.new('error message'))
        end

        it 'handles errors and delegates to wrapped client' do
          expect do
            client.blob('a minor')
          end.to raise_error(BlobstoreError, 'error message')
          expect(logger).to have_received(:error).with('Error with blobstore: Excon::Error - error message')
        end
      end

      describe '#delete_blob' do
        before do
          allow(wrapped_client).to receive(:delete_blob).and_raise(Excon::Errors::Error.new('error message'))
        end

        it 'handles errors and delegates to wrapped client' do
          expect do
            client.delete_blob('herbie')
          end.to raise_error(BlobstoreError, 'error message')
          expect(logger).to have_received(:error).with('Error with blobstore: Excon::Error - error message')
        end
      end

      describe '#cp_file_between_keys' do
        before do
          allow(wrapped_client).to receive(:cp_file_between_keys).and_raise(Excon::Errors::Error.new('error message'))
        end

        it 'handles errors and delegates to wrapped client' do
          expect do
            client.cp_file_between_keys('source_key', 'destination_key')
          end.to raise_error(BlobstoreError, 'error message')
          expect(logger).to have_received(:error).with('Error with blobstore: Excon::Error - error message')
        end
      end

      describe '#cp_r_to_blobstore' do
        before do
          allow(wrapped_client).to receive(:cp_r_to_blobstore).and_raise(Excon::Errors::Error.new('error message'))
        end

        it 'handles errors and delegates to wrapped client' do
          expect do
            client.cp_r_to_blobstore('dont/forget/a/source_dir')
          end.to raise_error(BlobstoreError, 'error message')
          expect(logger).to have_received(:error).with('Error with blobstore: Excon::Error - error message')
        end
      end

      describe '#download_from_blobstore' do
        before do
          allow(wrapped_client).to receive(:download_from_blobstore).and_raise(Excon::Errors::Error.new('error message'))
        end

        it 'handles errors and delegates to wrapped client' do
          expect do
            client.download_from_blobstore('some source_key', 'some:destination_path')
          end.to raise_error(BlobstoreError, 'error message')
          expect(logger).to have_received(:error).with('Error with blobstore: Excon::Error - error message')
        end
      end

      describe '#delete' do
        before do
          allow(wrapped_client).to receive(:delete).and_raise(Excon::Errors::Error.new('error message'))
        end

        it 'handles errors and delegates to wrapped client' do
          expect do
            client.delete('a key')
          end.to raise_error(BlobstoreError, 'error message')
          expect(logger).to have_received(:error).with('Error with blobstore: Excon::Error - error message')
        end
      end

      describe '#cp_to_blobstore' do
        before do
          allow(wrapped_client).to receive(:cp_to_blobstore).and_raise(Excon::Errors::Error.new('error message'))
        end

        it 'handles errors and delegates to wrapped client' do
          expect do
            client.cp_to_blobstore('source_path', 'destination_key')
          end.to raise_error(BlobstoreError, 'error message')
          expect(logger).to have_received(:error).with('Error with blobstore: Excon::Error - error message')
        end
      end

      describe '#files_for' do
        let(:args) { 'some-args' }

        before do
          allow(wrapped_client).to receive(:files_for).with(args).and_raise(Excon::Errors::Error.new('error message'))
        end

        it 'handles errors and delegates to wrapped client' do
          expect do
            client.files_for(args)
          end.to raise_error(BlobstoreError, 'error message')
          expect(logger).to have_received(:error).with('Error with blobstore: Excon::Error - error message')
        end
      end
    end
  end
end
