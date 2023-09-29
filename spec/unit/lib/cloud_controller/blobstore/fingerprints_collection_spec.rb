require 'spec_helper'
require 'cloud_controller/blobstore/fingerprints_collection'

module CloudController
  module Blobstore
    RSpec.describe FingerprintsCollection do
      let(:unpresented_fingerprints) do
        [
          { 'fn' => 'path/to/file.txt', 'size' => 123, 'sha1' => 'abc' },
          { 'fn' => 'path/to/file2.txt', 'size' => 321, 'sha1' => 'def' },
          { 'fn' => 'path/to/file3.txt', 'size' => 112, 'sha1' => 'fad' }
        ]
      end

      let(:root_path) { '/some/where' }
      let(:collection) { FingerprintsCollection.new(unpresented_fingerprints, root_path) }

      describe '.new' do
        it 'validates that the input is a array of hashes' do
          expect do
            FingerprintsCollection.new('', '')
          end.to raise_error CloudController::Errors::ApiError, /invalid/
        end
      end

      describe '#storage_size' do
        it 'sums the sizes' do
          expect(collection.storage_size).to eq 123 + 321 + 112
        end
      end

      describe '#fingerprints' do
        let(:unpresented_fingerprints) do
          [
            { 'fn' => 'path/to/file', 'size' => 'my_filesize', 'sha1' => 'mysha' }
          ]
        end
        let(:fingerprint) { collection.fingerprints[0] }

        describe 'file path' do
          it 'presents file path' do
            expect(fingerprint['fn']).to eq('path/to/file')
          end

          context 'when the file path resolves inside the root path' do
            let(:unpresented_fingerprints) do
              [
                { 'fn' => "../../..#{root_path}/legit/path", 'size' => 'my_filesize', 'sha1' => 'mysha' }
              ]
            end

            it 'presents file path' do
              expect(fingerprint['fn']).to eq("../../..#{root_path}/legit/path")
            end
          end

          context 'when the file path resolves outside the root path' do
            let(:unpresented_fingerprints) do
              [
                { 'fn' => '../incorrect/path', 'size' => 'my_filesize', 'sha1' => 'mysha' }
              ]
            end

            it 'raises an error' do
              expect do
                fingerprint
              end.to raise_error do |error|
                expect(error.name).to eq 'AppResourcesFilePathInvalid'
                expect(error.response_code).to eq 400
              end
            end
          end
        end

        it 'presents file size' do
          expect(fingerprint['size']).to eq('my_filesize')
        end

        it 'presents file sha1' do
          expect(fingerprint['sha1']).to eq('mysha')
        end

        describe 'mode' do
          it 'defaults to 0744' do
            expect(fingerprint['mode']).to eq(0o744)
          end

          context 'when mode is provided' do
            let(:unpresented_fingerprints) do
              [
                { 'fn' => 'path/to/mode-modified-file', 'size' => 'my_filesize', 'sha1' => 'mysha', 'mode' => mode }
              ]
            end
            let(:mode) { '0653' }

            it 'uses the provided mode' do
              expect(fingerprint['mode']).to eq(0o653)
            end

            context 'when the mode is bad' do
              context 'because it is nonsense' do
                let(:mode) { 'banana' }

                it 'raises an error' do
                  expect do
                    fingerprint
                  end.to raise_error do |error|
                    expect(error.name).to eq 'AppResourcesFileModeInvalid'
                    expect(error.response_code).to eq 400
                  end
                end
              end

              context 'because it is too restrictive' do
                let(:mode) { '144' }

                it 'raises an error' do
                  expect do
                    fingerprint
                  end.to raise_error do |error|
                    expect(error.name).to eq 'AppResourcesFileModeInvalid'
                    expect(error.message).to eq "The resource file mode is invalid: File mode '144' with path 'path/to/mode-modified-file' is invalid. Minimum file mode is '0600'"
                    expect(error.response_code).to eq 400
                  end
                end
              end
            end
          end
        end
      end

      describe '#each' do
        it 'returns each sha one by one' do
          expect do |yielded|
            collection.each(&yielded)
          end.to yield_successive_args(['path/to/file.txt', 'abc', 0o744], ['path/to/file2.txt', 'def', 0o744], ['path/to/file3.txt', 'fad', 0o744])
        end
      end
    end
  end
end
