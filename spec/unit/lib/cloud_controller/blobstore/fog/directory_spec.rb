require 'spec_helper'

module CloudController
  module Blobstore
    RSpec.describe Directory do
      let(:fog_directory) do
        double('Fog::**::Directory')
      end

      let(:directory_key) { 'a-directory-key' }

      let(:directories) do
        double('Fog::**::Directories', directories: [])
      end

      let(:connection) do
        double('Fog::Storage', directories: directories, service: Fog::Storage::AWS)
      end

      subject(:directory) do
        Directory.new(connection, directory_key)
      end

      describe '#create' do
        it 'creates a private directory with the specified key and retrieves it' do
          expect(directories).to receive(:create).with(key: directory_key, public: false).and_return(fog_directory)
          expect(directory.create).to eq(fog_directory)
        end
      end

      describe '#get' do
        it 'retrieves the directory' do
          expect(directories).to receive(:get).with(directory_key, max_keys: 1).and_return(fog_directory)
          expect(directory.get).to eq(fog_directory)
        end

        context 'when provider is OpenStack' do
          it 'adds the "limit" option (see: https://github.com/fog/fog-openstack/issues/51)' do
            expect(connection).to receive(:service).and_return(Fog::Storage::OpenStack)
            expect(directories).to receive(:get).with(directory_key, 'limit' => 1, max_keys: 1)
            directory.get
          end
        end
      end
    end
  end
end
