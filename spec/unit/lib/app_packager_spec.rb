require 'spec_helper'
require 'cloud_controller/app_packager'

RSpec.describe AppPackager do
  subject(:app_packager) { AppPackager.new(input_zip, logger:) }

  around do |example|
    Dir.mktmpdir('app_packager_spec') do |tmpdir|
      @tmpdir = tmpdir
      example.call
    end
  end

  let(:logger) { instance_double(Steno::Logger, error: nil) }

  describe '#size' do
    let(:input_zip) { File.join(Paths::FIXTURES, 'good.zip') }
    let(:size_of_good_zip) { 17 }

    it 'returns the sum of each file size' do
      expect(app_packager.size).to eq(size_of_good_zip)
    end
  end

  describe '#unzip' do
    let(:input_zip) { File.join(Paths::FIXTURES, 'good.zip') }

    it 'unzips the file given' do
      app_packager.unzip(@tmpdir)

      expect(Dir["#{@tmpdir}/**/*"].size).to eq 4
      expect(Dir["#{@tmpdir}/*"].size).to eq 3
      expect(Dir["#{@tmpdir}/subdir/*"].size).to eq 1
    end

    context 'when the zip contains broken symlinks' do
      let(:input_zip) { File.join(Paths::FIXTURES, 'app_packager_zips', 'broken-file-symlink.zip') }

      it 'successfully unzips' do
        expect do
          app_packager.unzip(@tmpdir)
        end.not_to raise_error
      end
    end

    context 'when the zip destination does not exist' do
      it 'raises an exception' do
        expect do
          app_packager.unzip(File.join(@tmpdir, 'blahblah'))
        end.to raise_exception(CloudController::Errors::ApiError, /destination does not exist/i)
      end
    end

    context 'when the zip is empty' do
      let(:input_zip) { File.join(Paths::FIXTURES, 'empty.zip') }

      it 'raises an exception' do
        expect do
          app_packager.unzip(@tmpdir)
        end.to raise_exception(CloudController::Errors::ApiError, /Invalid zip archive/)
      end
    end

    describe 'relative paths' do
      context 'when the relative path does NOT leave the root directory' do
        let(:input_zip) { File.join(Paths::FIXTURES, 'good_relative_paths.zip') }

        it 'unzips the archive, ignoring ".."' do
          app_packager.unzip(@tmpdir)

          expect(File.exist?("#{@tmpdir}/bar/cat")).to be true
        end
      end

      context 'when the relative path does leave the root directory' do
        let(:input_zip) { File.join(Paths::FIXTURES, 'bad_relative_paths.zip') }

        it 'unzips the archive, ignoring ".."' do
          app_packager.unzip(@tmpdir)

          expect(File.exist?("#{@tmpdir}/fakezip.zip")).to be true
        end
      end
    end

    context 'when there is an error unzipping' do
      before do
        allow(Open3).to receive(:capture3).and_return(['', multiline_error_message, double(success?: false)])
      end

      context 'end-of-central-directory signature not found' do
        let(:multiline_error_message) do
          <<~EOF
            [archive]
              End-of-central-directory signature not found.  Either this file is not
              a zipfile, or it constitutes one disk of a multi-part archive.  In the
              latter case the central directory and zipfile comment will be found on
              the last disk(s) of this archive.
            unzip:  cannot find zipfile directory in one of archive or
                    archive.zip, and cannot find archive.ZIP, period.
          EOF
        end

        it 'raises an exception' do
          expect do
            app_packager.unzip(@tmpdir)
          end.to raise_error(CloudController::Errors::ApiError, 'The app upload is invalid: Invalid zip archive (end-of-central-directory signature not found).')
        end
      end

      context 'end-of-central-directory signature not found' do
        let(:multiline_error_message) do
          <<~EOF
            warning [archive]:  zipfile is empty
          EOF
        end

        it 'raises an exception' do
          expect do
            app_packager.unzip(@tmpdir)
          end.to raise_error(CloudController::Errors::ApiError, 'The app upload is invalid: Invalid zip archive (zipfile is empty).')
        end
      end

      context 'mismatching "local" filename' do
        let(:multiline_error_message) do
          <<~EOF
            a_is_++:  mismatching "local" filename (a_is_α),
                     continuing with "central" filename version
            b_is_++:  mismatching "local" filename (b_is_β),
                     continuing with "central" filename version
          EOF
        end

        it 'raises an exception' do
          expect do
            app_packager.unzip(@tmpdir)
          end.to raise_error(CloudController::Errors::ApiError, 'The app upload is invalid: Invalid zip archive (mismatching local filename).')
        end
      end
    end
  end

  describe '#append_dir_contents' do
    let(:input_zip) { File.join(@tmpdir, 'good.zip') }
    let(:additional_files_path) { File.join(Paths::FIXTURES, 'fake_package') }

    before { FileUtils.cp(File.join(Paths::FIXTURES, 'good.zip'), input_zip) }

    it 'adds the files to the zip' do
      app_packager.append_dir_contents(additional_files_path)

      output = `zipinfo #{input_zip}`

      expect(output).not_to include './'
      expect(output).not_to include 'fake_package'

      expect(output).to match(/^l.+coming_from_inside$/)
      expect(output).to include 'here.txt'
      expect(output).to include 'subdir/'
      expect(output).to include 'subdir/there.txt'

      expect(output).to include 'bye'
      expect(output).to include 'hi'
      expect(output).to include 'subdir/'
      expect(output).to include 'subdir/greetings'

      expect(output).to include '7 files'
    end

    context 'when there are no additional files' do
      let(:additional_files_path) { File.join(@tmpdir, 'empty') }

      it 'results in the existing zip' do
        Dir.mkdir(additional_files_path)

        output = `zipinfo #{input_zip}`

        expect(output).to include 'bye'
        expect(output).to include 'hi'
        expect(output).to include 'subdir/'
        expect(output).to include 'subdir/greeting'

        expect(output).to include '4 files'

        app_packager.append_dir_contents(additional_files_path)

        output = `zipinfo #{input_zip}`

        expect(output).to include 'bye'
        expect(output).to include 'hi'
        expect(output).to include 'subdir/'
        expect(output).to include 'subdir/greeting'

        expect(output).to include '4 files'
      end
    end

    context 'when there is an error zipping' do
      it 'raises an exception' do
        allow(Open3).to receive(:capture3).and_return(['output', 'error', double(success?: false)])
        expect do
          app_packager.append_dir_contents(additional_files_path)
        end.to raise_error(CloudController::Errors::ApiError, /The app package is invalid: Error appending additional resources to package/)
      end
    end
  end

  describe '#fix_subdir_permissions' do
    context 'when the zip has directories without the directory attribute or execute permission (it was created on windows)' do
      let(:input_zip) { File.join(@tmpdir, 'bad_directory_permissions.zip') }

      before { FileUtils.cp(File.join(Paths::FIXTURES, 'app_packager_zips', 'bad_directory_permissions.zip'), input_zip) }

      it 'deletes all directories from the archive' do
        app_packager.fix_subdir_permissions(@tmpdir, "#{@tmpdir}/application_contents")

        has_dirs = Zip::File.open(input_zip) do |in_zip|
          in_zip.any?(&:directory?)
        end

        expect(has_dirs).to be_falsey
      end
    end

    context 'when the zip has directories with special characters' do
      let(:input_zip) { File.join(@tmpdir, 'special_character_names.zip') }

      before { FileUtils.cp(File.join(Paths::FIXTURES, 'app_packager_zips', 'special_character_names.zip'), input_zip) }

      it 'successfully removes and re-adds them' do
        app_packager.fix_subdir_permissions(@tmpdir, "#{@tmpdir}/application_contents")
        expect(`zipinfo #{input_zip}`).to match %r{special_character_names/&&hello::\?\?/}
      end
    end

    context 'when there are many directories' do
      let(:input_zip) { File.join(@tmpdir, 'many_dirs.zip') }

      before { FileUtils.cp(File.join(Paths::FIXTURES, 'app_packager_zips', 'many_dirs.zip'), input_zip) }

      it 'fixes the directory permissions and batches the directory deletes so it does not exceed the max command length' do
        allow(Open3).to receive(:capture3).and_call_original
        batch_size = 10
        stub_const('AppPackager::DIRECTORY_DELETE_BATCH_SIZE', batch_size)

        app_packager.fix_subdir_permissions(@tmpdir, "#{@tmpdir}/application_contents")

        output = `zipinfo #{input_zip}`

        21.times do |i|
          expect(output).to include("folder_#{i}/")
          expect(output).to include("folder_#{i}/empty_file")
        end

        number_of_batches = (21.0 / batch_size).ceil
        expect(number_of_batches).to eq(3)
        expect(Open3).to have_received(:capture3).exactly(number_of_batches + 1).times
      end
    end

    context 'when there is an error deleting directories' do
      let(:input_zip) { File.join(@tmpdir, 'bad_directory_permissions.zip') }

      before { FileUtils.cp(File.join(Paths::FIXTURES, 'app_packager_zips', 'bad_directory_permissions.zip'), input_zip) }

      it 'raises an exception' do
        allow(Open3).to receive(:capture3).and_return(['output', 'error', double(success?: false)])
        expect do
          app_packager.fix_subdir_permissions(@tmpdir, "#{@tmpdir}/application_contents")
        end.to raise_error(CloudController::Errors::ApiError, /The app package is invalid: Error removing zip directories./)
      end
    end

    context 'when there is a zip error' do
      let(:input_zip) { 'garbage' }

      it 'raises an exception' do
        allow(Open3).to receive(:capture3).and_return(['output', 'error', double(success?: false)])
        expect do
          app_packager.fix_subdir_permissions(@tmpdir, "#{@tmpdir}/application_contents")
        end.to raise_error(CloudController::Errors::ApiError, /The app upload is invalid: Invalid zip archive./)
      end
    end
  end
end
