require 'spec_helper'
require 'messages/packages/package_upload_message'

module VCAP::CloudController
  RSpec.describe PackageUploadMessage do
    before { TestConfig.override(directories: { tmpdir: '/tmp/' }) }

    describe 'validations' do
      let(:opts) { { bits_path: '/tmp/foobar' } }

      it 'is valid' do
        upload_message = PackageUploadMessage.new(opts)
        expect(upload_message).to be_valid
      end

      context 'when the path is not provided' do
        let(:opts) { {} }
        it 'is not valid' do
          upload_message = PackageUploadMessage.new(opts)
          expect(upload_message).not_to be_valid
          expect(upload_message.errors[:bits_path]).to include('An application zip file must be uploaded')
        end
      end

      context 'when unexpected keys are requested' do
        let(:opts) { { bits_path: '/tmp/bar', unexpected: 'foo' } }

        it 'is not valid' do
          message = PackageUploadMessage.new(opts)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
        end
      end

      context 'when the bits_path is not within the tmpdir' do
        let(:opts) { { bits_path: '/secret/file' } }

        it 'is not valid' do
          message = PackageUploadMessage.new(opts)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('Bits path is invalid')
        end
      end
    end

    describe '#bits_path=' do
      subject(:upload_message) { PackageUploadMessage.new(bits_path: 'not-nil') }

      context 'when the bits_path is relative' do
        it 'makes it absolute (within the tmpdir)' do
          upload_message.bits_path = 'foobar'

          expect(upload_message.bits_path).to eq('/tmp/foobar')
        end
      end

      context 'when given nil' do
        it 'sets bits_path to nil' do
          upload_message.bits_path = nil
          expect(upload_message.bits_path).to eq(nil)
        end
      end
    end

    describe '.create_from_params' do
      let(:params) { { 'bits_path' => '/tmp/foobar' } }

      it 'returns the correct PackageUploadMessage' do
        message = PackageUploadMessage.create_from_params(params)

        expect(message).to be_a(PackageUploadMessage)
        expect(message.bits_path).to eq('/tmp/foobar')
      end

      it 'converts requested keys to symbols' do
        message = PackageUploadMessage.create_from_params(params)

        expect(message.requested?(:bits_path)).to be_truthy
      end

      context 'when the <ngnix_upload_module_dummy> param is set' do
        let(:params) { { 'bits_path' => 'foobar', '<ngnix_upload_module_dummy>' => '' } }

        it 'raises an error' do
          expect {
            PackageUploadMessage.create_from_params(params)
          }.to raise_error(PackageUploadMessage::MissingFilePathError, 'File field missing path information')
        end
      end

      context 'when rack is handling the file upload' do
        let(:file) { instance_double(ActionDispatch::Http::UploadedFile, tempfile: instance_double(Tempfile, path: '/tmp/foobar')) }
        let(:params) { { 'bits' => file } }

        it 'returns the correct PackageUploadMessage' do
          message = PackageUploadMessage.create_from_params(params)

          expect(message).to be_a(PackageUploadMessage)
          expect(message.bits_path).to eq('/tmp/foobar')
        end
      end
    end
  end
end
