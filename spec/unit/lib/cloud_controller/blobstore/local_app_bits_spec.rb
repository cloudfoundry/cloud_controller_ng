require 'spec_helper'
require 'cloud_controller/blobstore/local_app_bits'

module CloudController
  module Blobstore
    RSpec.describe LocalAppBits do
      let(:compressed_zip_path) { '/tmp/zipped.compressed_zip_path' }
      let(:root_path) { '/tmp/safezipper' }
      let(:uncompressed_path) { File.join(root_path, LocalAppBits::UNCOMPRESSED_DIR) }
      let(:tmp_dir) { '/tmp' }

      describe '.from_compressed_bits' do
        before do
          allow(File).to receive(:exist?).and_return(true)
          allow(SafeZipper).to receive(:unzip).and_return(123)
          allow(Dir).to receive(:mktmpdir).and_yield(root_path)
          allow(FileUtils).to receive(:mkdir)
        end

        it 'yields a block' do
          expect { |yielded|
            LocalAppBits.from_compressed_bits(compressed_zip_path, tmp_dir, &yielded)
          }.to yield_control
        end

        it 'unzips the folder' do
          expect(SafeZipper).to receive(:unzip).with(compressed_zip_path, uncompressed_path)

          LocalAppBits.from_compressed_bits(compressed_zip_path, tmp_dir) do |local_app_bits|
            expect(local_app_bits.uncompressed_path).to eq uncompressed_path
          end
        end

        it 'create and delete the tmp dir where its uncompressed' do
          expect(Dir).to receive(:mktmpdir).with('safezipper', tmp_dir)

          LocalAppBits.from_compressed_bits(compressed_zip_path, tmp_dir) do |local_app_bits|
            expect(local_app_bits.uncompressed_path).to start_with uncompressed_path
          end
        end

        it 'gets the storage_size of the uncompressed files' do
          LocalAppBits.from_compressed_bits(compressed_zip_path, tmp_dir) do |local_app_bits|
            expect(local_app_bits.storage_size).to eq 123
          end
        end

        context 'when the zip file is pointing to a non existent file' do
          it 'does not unzip anything' do
            expect(File).to receive(:exist?).with(compressed_zip_path).and_return(false)
            expect(SafeZipper).not_to receive(:unzip)
            LocalAppBits.from_compressed_bits(compressed_zip_path, tmp_dir) do |local_app_bits|
              expect(local_app_bits.storage_size).to eq 0
            end
          end
        end

        context 'when the zip file does not exist' do
          let(:compressed_zip_path) { nil }

          it 'does not unzip anything' do
            expect(SafeZipper).not_to receive(:unzip)
            LocalAppBits.from_compressed_bits(compressed_zip_path, tmp_dir) do |local_app_bits|
              expect(local_app_bits.storage_size).to eq 0
            end
          end
        end
      end

      describe '#create_package' do
        subject(:local_app_bits) { LocalAppBits.new(root_path, 123) }

        it 'should zip up the file and yield the open stream of it' do
          path = '/tmp/safezipper/package.zip'
          expect(SafeZipper).to receive(:zip).with(uncompressed_path, path)
          expect(File).to receive(:new).with(path).and_return(double(:file, path: path, hexdigest: 'some_sha'))

          package = local_app_bits.create_package
          expect(package.path).to eq path
          expect(package.hexdigest).to eq 'some_sha'
        end

        it 'its zip destination should be outside the source' do
          expect(File).to receive(:new)
          expect(SafeZipper).to receive(:zip) do |source, destination|
            expect(File.dirname(destination)).to_not match /^#{source}/
          end
          local_app_bits.create_package
        end
      end
    end
  end
end
