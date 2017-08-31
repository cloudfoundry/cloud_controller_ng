require 'spec_helper'

RSpec.describe UploadHandler do
  let(:key) { 'application' }
  let(:tmpdir) { '/some/tmp/dir' }
  subject(:uploader) { UploadHandler.new(config) }

  context 'Nginx mode' do
    let(:config) do
      VCAP::CloudController::Config.new({ nginx: { use_nginx: true }, directories: { tmpdir: tmpdir } })
    end

    context 'when the file exists' do
      let(:params) { { "#{key}_path" => "#{tmpdir}/file" } }

      it 'expects the {name}_path variable to contain the uploaded file path' do
        expect(uploader.uploaded_file(params, key)).to eq("#{tmpdir}/file")
      end
    end

    context "when the file doesn't exist" do
      let(:params) { { 'foobar_path' => "#{tmpdir}/file" } }

      it 'expects the {name}_path variable to contain the uploaded file path' do
        expect(uploader.uploaded_file(params, key)).to be_nil
      end
    end

    context 'when the user attempts to provide an invalid file path' do
      let(:params) { { "#{key}_path" => '/some/path', '<ngx_upload_module_dummy>' => '' } }

      it 'raises an error' do
        expect {
          uploader.uploaded_file(params, key)
        }.to raise_error(UploadHandler::MissingFilePathError, 'File field missing path information')
      end
    end

    context 'when the file exists but is not inside any of the temp directories' do
      context 'when the path is an absolute path' do
        let(:params) { { "#{key}_path" => "#{tmpdir}/../path" } }
        it 'raises an error' do
          expect {
            uploader.uploaded_file(params, key)
          }.to raise_error(UploadHandler::InvalidFilePathError, 'Invalid file path')
        end
      end

      context 'when the path is relative' do
        let(:params) { { "#{key}_path" => '../relative/file' } }

        it 'raises an error' do
          expect {
            uploader.uploaded_file(params, key)
          }.to raise_error(UploadHandler::InvalidFilePathError, 'Invalid file path')
        end
      end
    end
  end

  context 'Rack Mode' do
    let(:config) do
      VCAP::CloudController::Config.new({ nginx: { use_nginx: false }, directories: { tmpdir: tmpdir } })
    end

    context 'and the tempfile key is a symbol' do
      let(:params) { { key => { tempfile: Struct.new(:path).new("#{tmpdir}/file") } } }

      it 'returns the uploaded file from the :tempfile synthetic variable' do
        expect(uploader.uploaded_file(params, 'application')).to eq("#{tmpdir}/file")
      end
    end

    context 'and the value of the tmpfile is path' do
      let(:params) { { key => { 'tempfile' => "#{tmpdir}/file" } } }

      it 'returns the uploaded file from the tempfile synthetic variable' do
        expect(uploader.uploaded_file(params, 'application')).to eq("#{tmpdir}/file")
      end
    end

    context 'and there is no file' do
      let(:params) { { key => nil } }

      it 'returns nil' do
        expect(uploader.uploaded_file(params, 'application')).to be_nil
      end
    end

    context 'when the file path is relative' do
      let(:params) { { key => { 'tempfile' => 'path' } } }

      it 'expands it within the tmp dir' do
        expect(uploader.uploaded_file(params, key)).to eq("#{tmpdir}/path")
      end
    end

    context 'when the file exists but is not inside any of the temp directories' do
      context 'when the path is an absolute path' do
        let(:params) { { key => { 'tempfile' => "#{tmpdir}/../path" } } }
        it 'raises an error' do
          expect {
            uploader.uploaded_file(params, key)
          }.to raise_error(UploadHandler::InvalidFilePathError, 'Invalid file path')
        end
      end

      context 'when the path is a relative path' do
        let(:params) { { key => { 'tempfile' => '../relative/file' } } }

        it 'raises an error' do
          expect {
            uploader.uploaded_file(params, key)
          }.to raise_error(UploadHandler::InvalidFilePathError, 'Invalid file path')
        end
      end
    end
  end
end
