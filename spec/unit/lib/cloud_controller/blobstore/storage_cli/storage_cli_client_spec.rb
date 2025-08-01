require 'spec_helper'
require 'cloud_controller/blobstore/storage_cli/azure_storage_cli_client'

module CloudController
  module Blobstore
    RSpec.describe StorageCliClient do
      describe 'registry build and lookup' do
        it 'builds the correct client' do
          client_from_registry = StorageCliClient.build(connection_config: { provider: 'AzureRM' }, directory_key: 'dummy-key', root_dir: 'dummy-root')
          expect(client_from_registry).to be_a(AzureStorageCliClient)
        end

        it 'raises an error for an unregistered provider' do
          expect do
            StorageCliClient.build(connection_config: { provider: 'UnknownProvider' }, directory_key: 'dummy-key', root_dir: 'dummy-root')
          end.to raise_error(RuntimeError, 'No storage CLI client registered for provider UnknownProvider')
        end

        it 'raises an error if provider is missing' do
          expect do
            StorageCliClient.build(connection_config: {}, directory_key: 'dummy-key', root_dir: 'dummy-root')
          end.to raise_error(RuntimeError, 'Missing connection_config[:provider]')
        end
      end
    end
  end
end
