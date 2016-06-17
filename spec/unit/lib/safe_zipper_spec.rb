require 'spec_helper'
require 'cloud_controller/safe_zipper'

RSpec.describe SafeZipper do
  around do |example|
    Dir.mktmpdir('foo') do |tmpdir|
      @tmpdir = tmpdir
      example.call
    end
  end

  describe '.unzip' do
    let(:zip_path) { File.expand_path('../../fixtures/good.zip', File.dirname(__FILE__)) }
    let(:zip_destination) { @tmpdir }

    subject(:unzip) { SafeZipper.unzip(zip_path, zip_destination) }

    it 'unzips the file given' do
      unzip
      expect(Dir["#{zip_destination}/**/*"].size).to eq 4
      expect(Dir["#{zip_destination}/*"].size).to eq 3
      expect(Dir["#{zip_destination}/subdir/*"].size).to eq 1
    end

    it 'returns the size of the unzipped files' do
      expect(SafeZipper.unzip(zip_path, zip_destination)).to eq 17
    end

    it 'returns the size if it is large' do
      allow(Open3).to receive(:capture3).with(%(unzip -l #{zip_path})).and_return(
        [
          "Archive:\n Filename\n ---\n 0  09-15-15 17:44 foo\n ---\n10000000001 1 file\n",
          nil,
          double('status', success?: true)]
      )
      expect(SafeZipper.unzip(zip_path, zip_destination)).to eq 10_000_000_001
    end

    context "when the zip_destination doesn't exist" do
      let(:zip_destination) { 'bar' }

      it 'raises an exception' do
        expect { unzip }.to raise_exception CloudController::Errors::ApiError, /destination does not exist/i
      end
    end

    context 'when the underlying unzip fails' do
      let(:zip_path) { File.expand_path('../../fixtures/missing.zip', File.dirname(__FILE__)) }

      it 'raises an exception' do
        expect { unzip }.to raise_exception CloudController::Errors::ApiError, /unzipping had errors\n STDOUT: ""\n STDERR: "unzip:\s+cannot find or open/im
      end
    end

    context 'when the zip is empty' do
      let(:zip_path) { File.expand_path('../../fixtures/empty.zip', File.dirname(__FILE__)) }

      it 'raises an exception' do
        expect { unzip }.to raise_exception CloudController::Errors::ApiError, /unzipping had errors/i
      end
    end

    describe 'symlinks' do
      context 'when they are inside the root directory' do
        let(:zip_path) { File.expand_path('../../fixtures/good_symlinks.zip', File.dirname(__FILE__)) }

        it 'unzips them archive correctly without errors' do
          unzip
          expect(File.symlink?("#{zip_destination}/what")).to be true
        end
      end

      context 'when the are outside the root directory' do
        let(:zip_path) { File.expand_path('../../fixtures/bad_symlinks.zip', File.dirname(__FILE__)) }

        it 'raises an exception' do
          expect { unzip }.to raise_exception CloudController::Errors::ApiError, /symlink.+outside/i
        end
      end
    end

    describe 'relative paths' do
      context 'when the are inside the root directory' do
        let(:zip_path) { File.expand_path('../../fixtures/good_relative_paths.zip', File.dirname(__FILE__)) }

        it 'unzips them archive correctly without errors' do
          unzip
          expect(File.exist?("#{zip_destination}/bar/../cat")).to be true
        end
      end

      context 'when the are outside the root directory' do
        let(:zip_path) { File.expand_path('../../fixtures/bad_relative_paths.zip', File.dirname(__FILE__)) }

        it 'raises an exception' do
          expect { unzip }.to raise_exception CloudController::Errors::ApiError, /relative path.+outside/i
        end
      end

      context 'when the are outside the root directory and have spaces' do
        let(:zip_path) { File.expand_path('../../fixtures/bad_relative_paths_with_spaces.zip', File.dirname(__FILE__)) }

        it 'raises an exception' do
          expect { unzip }.to raise_exception CloudController::Errors::ApiError, /relative path.+outside/i
        end
      end
    end
  end

  describe '.zip' do
    let(:root_path) { File.expand_path('../../fixtures/fake_package/', File.dirname(__FILE__)) }
    let(:tmp_zip) { File.join(@tmpdir, 'tmp.zip') }

    it 'zips the file without directory listings' do
      SafeZipper.zip(root_path, tmp_zip)

      output = `zipinfo #{tmp_zip}`
      expect(output).not_to include './'
      expect(output).not_to include 'spec/fixtures/fake_package'
      expect(output).not_to match %r{subdir/$}
      expect(output).to include 'subdir/there'
      expect(output).to match /^l.+coming_from_inside$/
      expect(output).to include '3 files'
    end

    context 'when the root path is empty' do
      let(:root_path) { File.expand_path('../../fixtures/no_exist', File.dirname(__FILE__)) }

      it 'will raise an error' do
        expect {
          SafeZipper.zip(root_path, tmp_zip)
        }.to raise_exception CloudController::Errors::ApiError, /path does not exist/i
      end
    end

    context 'when the destination directory does not exist' do
      let(:tmp_zip) { '/non/existent/path/to/tmp.zip' }

      it 'will raise an error' do
        expect {
          SafeZipper.zip(root_path, tmp_zip)
        }.to raise_exception CloudController::Errors::ApiError, /path does not exist/i
      end
    end

    context 'when the zipping fails' do
      let(:tmp_zip) { '/non/existent/path/to/tmp.zip' }

      it 'will raise an error' do
        allow(File).to receive(:exist?).and_return(true)

        expect {
          SafeZipper.zip(root_path, tmp_zip)
        }.to raise_exception CloudController::Errors::ApiError, /could not zip the package\n STDOUT: "zip .+?"\n STDERR: ""/im
      end
    end
  end
end
