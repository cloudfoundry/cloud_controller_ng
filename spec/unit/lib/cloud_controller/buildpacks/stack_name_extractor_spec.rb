require 'spec_helper'

module VCAP::CloudController::Buildpacks
  RSpec.describe StackNameExtractor do
    let(:tmpdir) { Dir.mktmpdir }
    let(:zip_path) { File.join(tmpdir, 'file.zip') }

    def zip_with_manifest_content(manifest_content)
      TestZip.create(zip_path, 1, 1024) do |zipfile|
        if manifest_content
          zipfile.get_output_stream('manifest.yml') do |f|
            f.write(manifest_content)
          end
        end
      end
    end

    describe '.extract_from_file' do
      context 'buildpack zip is not a valid zip file' do
        before do
          File.write(zip_path, 'INVALID_FOR_A_ZIP_FILE_THIS_IS')
        end

        it 'raises an error' do
          expect { StackNameExtractor.extract_from_file(zip_path) }.to raise_error(CloudController::Errors::BuildpackError, 'buildpack zipfile is not valid')
        end
      end

      context 'buildpack zip contains a manifest specifying the stack' do
        before do
          zip_with_manifest_content("---\nstack: ITSaSTACK\n")
        end

        it 'returns the stack in the manifest' do
          expect(StackNameExtractor.extract_from_file(zip_path)).to eq('ITSaSTACK')
        end
      end

      context 'buildpack zip contains manifest that does not specify stack' do
        before do
          zip_with_manifest_content("---\nsomethingelse: NOTstackTHOUGH\n")
        end

        it 'returns nil' do
          expect(StackNameExtractor.extract_from_file(zip_path)).to be_nil
        end
      end

      context 'buildpack zip contains manifest which is not valid' do
        before do
          zip_with_manifest_content("\0xde\0xad\0xbe\0xef")
        end

        it 'raises an error' do
          expect { StackNameExtractor.extract_from_file(zip_path) }.to raise_error(CloudController::Errors::BuildpackError, 'buildpack manifest is not valid')
        end
      end

      context 'buildpack zip does not contain manifest' do
        before do
          TestZip.create(zip_path, 3, 1024)
        end

        it 'returns nil' do
          expect(StackNameExtractor.extract_from_file(zip_path)).to be_nil
        end
      end

      context 'buildpack zip contains manifest but it is too large (>1mb)' do
        before do
          alphachars = [*'A'..'Z']
          megabyte_string = (0...(1024 * 1024)).map { alphachars.sample }.join
          zip_with_manifest_content("---\nstack: cflinuxfs2\nabsurdly_long_value: " + megabyte_string)
        end

        it 'raises an error' do
          expect { StackNameExtractor.extract_from_file(zip_path) }.to raise_error(CloudController::Errors::BuildpackError, 'buildpack manifest is too large')
        end
      end
    end
  end
end
