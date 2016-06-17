require 'spec_helper'
require_relative '../client_shared'
require 'cloud_controller/blobstore/fog/error_handling_client'
require 'cloud_controller/blobstore/null_client'

module CloudController
  module Blobstore
    RSpec.describe ErrorHandlingClient do
      subject(:client) { ErrorHandlingClient.new(wrapped_client) }
      let(:wrapped_client) { Blobstore::NullClient.new }

      describe 'conforms to blobstore client interface' do
        let(:deletable_blob) { nil }

        it_behaves_like 'a blobstore client'
      end

      describe '#delete_all' do
        before do
          allow(wrapped_client).to receive(:delete_all).and_raise(Excon::Errors::Error.new('error message'))
        end

        it 'handles errors and delegates to wrapped client' do
          expect {
            client.delete_all
          }.to raise_error(BlobstoreError, 'error message')
        end
      end

      describe '#delete_all_in_path' do
        before do
          allow(wrapped_client).to receive(:delete_all_in_path).and_raise(Excon::Errors::Error.new('error message'))
        end

        it 'handles errors and delegates to wrapped client' do
          expect {
            client.delete_all_in_path
          }.to raise_error(BlobstoreError, 'error message')
        end
      end

      describe '#exists?' do
        before do
          allow(wrapped_client).to receive(:exists?).and_raise(Excon::Errors::Error.new('error message'))
        end

        it 'handles errors and delegates to wrapped client' do
          expect {
            client.exists?
          }.to raise_error(BlobstoreError, 'error message')
        end
      end

      describe '#blob' do
        before do
          allow(wrapped_client).to receive(:blob).and_raise(Excon::Errors::Error.new('error message'))
        end

        it 'handles errors and delegates to wrapped client' do
          expect {
            client.blob
          }.to raise_error(BlobstoreError, 'error message')
        end
      end

      describe '#delete_blob' do
        before do
          allow(wrapped_client).to receive(:delete_blob).and_raise(Excon::Errors::Error.new('error message'))
        end

        it 'handles errors and delegates to wrapped client' do
          expect {
            client.delete_blob
          }.to raise_error(BlobstoreError, 'error message')
        end
      end

      describe '#cp_file_between_keys' do
        before do
          allow(wrapped_client).to receive(:cp_file_between_keys).and_raise(Excon::Errors::Error.new('error message'))
        end

        it 'handles errors and delegates to wrapped client' do
          expect {
            client.cp_file_between_keys
          }.to raise_error(BlobstoreError, 'error message')
        end
      end

      describe '#cp_r_to_blobstore' do
        before do
          allow(wrapped_client).to receive(:cp_r_to_blobstore).and_raise(Excon::Errors::Error.new('error message'))
        end

        it 'handles errors and delegates to wrapped client' do
          expect {
            client.cp_r_to_blobstore
          }.to raise_error(BlobstoreError, 'error message')
        end
      end

      describe '#download_from_blobstore' do
        before do
          allow(wrapped_client).to receive(:download_from_blobstore).and_raise(Excon::Errors::Error.new('error message'))
        end

        it 'handles errors and delegates to wrapped client' do
          expect {
            client.download_from_blobstore
          }.to raise_error(BlobstoreError, 'error message')
        end
      end

      describe '#delete' do
        before do
          allow(wrapped_client).to receive(:delete).and_raise(Excon::Errors::Error.new('error message'))
        end

        it 'handles errors and delegates to wrapped client' do
          expect {
            client.delete
          }.to raise_error(BlobstoreError, 'error message')
        end
      end

      describe '#cp_to_blobstore' do
        before do
          allow(wrapped_client).to receive(:cp_to_blobstore).and_raise(Excon::Errors::Error.new('error message'))
        end

        it 'handles errors and delegates to wrapped client' do
          expect {
            client.cp_to_blobstore
          }.to raise_error(BlobstoreError, 'error message')
        end
      end
    end
  end
end
