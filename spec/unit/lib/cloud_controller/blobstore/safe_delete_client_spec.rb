require 'spec_helper'
require 'cloud_controller/blobstore/null_client'
require_relative 'client_shared'

module CloudController
  module Blobstore
    RSpec.describe SafeDeleteClient do
      subject(:client) { described_class.new(wrapped_client, root_dir) }
      let(:wrapped_client) { NullClient.new }
      let(:root_dir) { 'root-dir' }
      let(:deletable_blob) { Blob.new }

      it_behaves_like 'a blobstore client'

      describe '#delete_all' do
        it 'passes all args to the wrapped client' do
          allow(wrapped_client).to receive(:delete_all).and_call_original
          client.delete_all('arg')
          expect(wrapped_client).to have_received(:delete_all).with('arg')
        end

        context 'when root_dir is nil' do
          let(:root_dir) { nil }

          it 'raises an UnsafeDelete error' do
            expect {
              client.delete_all
            }.to raise_error(UnsafeDelete)
          end
        end

        context 'when root_dir is empty string' do
          let(:root_dir) { '' }

          it 'raises an UnsafeDelete error' do
            expect {
              client.delete_all
            }.to raise_error(UnsafeDelete)
          end
        end
      end

      describe '#delete_all_in_path' do
        it 'passes all args to the wrapped client' do
          allow(wrapped_client).to receive(:delete_all_in_path).and_call_original
          client.delete_all_in_path('arg')
          expect(wrapped_client).to have_received(:delete_all_in_path).with('arg')
        end

        context 'when root_dir is nil' do
          let(:root_dir) { nil }

          it 'raises an UnsafeDelete error' do
            expect {
              client.delete_all_in_path
            }.to raise_error(UnsafeDelete)
          end
        end

        context 'when root_dir is empty string' do
          let(:root_dir) { '' }

          it 'raises an UnsafeDelete error' do
            expect {
              client.delete_all_in_path
            }.to raise_error(UnsafeDelete)
          end
        end
      end
    end
  end
end
