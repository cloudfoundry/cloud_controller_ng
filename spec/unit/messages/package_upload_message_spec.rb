require 'spec_helper'
require 'messages/package_upload_message'

module VCAP::CloudController
  RSpec.describe PackageUploadMessage do
    before { TestConfig.override(directories: { tmpdir: '/tmp/' }) }

    describe 'validations' do
      context 'when there is a zip but no resources' do
        let(:opts) { { bits_path: '/tmp/foobar' } }

        it 'is valid' do
          upload_message = PackageUploadMessage.new(opts)
          expect(upload_message).to be_valid
        end
      end

      context 'when no zip is uploaded' do
        let(:opts) { { resources: [{ value: 'sbfkbjeb243' }] } }

        it 'is valid' do
          message = PackageUploadMessage.new(opts)

          expect(message).to be_valid
        end
      end

      context 'when the <ngnix_upload_module_dummy> param is set' do
        let(:opts) { { '<ngx_upload_module_dummy>' => '', bits_path: '/tmp/foobar' } }

        it 'is invalid' do
          upload_message = PackageUploadMessage.new(opts)
          expect(upload_message).not_to be_valid
          expect(upload_message.errors[:base]).to include('File field missing path information')
        end
      end

      context 'when the path is relative' do
        let(:opts) { { bits_path: '../tmp/mango/pear' } }

        it 'is valid' do
          upload_message = PackageUploadMessage.new(opts)
          expect(upload_message).to be_valid
        end
      end

      context 'when the path is relative but matches a prefix of the base dir' do
        let(:opts) { { bits_path: '../tmp-not!/mango/pear' } }

        it 'is not valid' do
          upload_message = PackageUploadMessage.new(opts)
          expect(upload_message).not_to be_valid
          expect(upload_message.errors[:bits_path]).to include('is invalid')
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

      context 'when neither bits path or resources are given' do
        let(:opts) { {} }

        it 'is not valid' do
          message = PackageUploadMessage.new(opts)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('Upload must include either resources or bits')
        end
      end

      context 'when no bits path is given and resources is empty' do
        let(:opts) { { resources: [] } }

        it 'is not valid' do
          message = PackageUploadMessage.new(opts)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('Upload must include either resources or bits')
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
