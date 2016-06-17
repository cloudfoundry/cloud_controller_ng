require 'spec_helper'
require 'messages/package_upload_message'

module VCAP::CloudController
  RSpec.describe PackageUploadMessage do
    context 'when the path is not provided' do
      let(:opts) { {} }
      it 'is not valid' do
        upload_message = PackageUploadMessage.new(opts)
        expect(upload_message).not_to be_valid
        expect(upload_message.errors[:bits_path]).to include('An application zip file must be uploaded')
      end
    end

    context 'and the path is provided' do
      let(:opts) { { bits_path: 'foobar' } }

      it 'is valid' do
        upload_message = PackageUploadMessage.new(opts)
        expect(upload_message).to be_valid
      end
    end

    context 'when unexpected keys are requested' do
      let(:opts) { { bits_path: 'bar', unexpected: 'foo' } }

      it 'is not valid' do
        message = PackageUploadMessage.new(opts)

        expect(message).not_to be_valid
        expect(message.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
      end
    end

    describe '.create_from_params' do
      let(:params) { { 'bits_path' => 'foobar' } }

      it 'returns the correct PackageUploadMessage' do
        message = PackageUploadMessage.create_from_params(params)

        expect(message).to be_a(PackageUploadMessage)
        expect(message.bits_path).to eq('foobar')
      end

      it 'converts requested keys to symbols' do
        message = PackageUploadMessage.create_from_params(params)

        expect(message.requested?(:bits_path)).to be_truthy
      end

      context 'when rack is handling the file upload' do
        let(:file) { instance_double(ActionDispatch::Http::UploadedFile, tempfile: instance_double(Tempfile, path: 'foobar')) }
        let(:params) { { 'bits' => file } }

        it 'returns the correct PackageUploadMessage' do
          message = PackageUploadMessage.create_from_params(params)

          expect(message).to be_a(PackageUploadMessage)
          expect(message.bits_path).to eq('foobar')
        end
      end
    end
  end
end
