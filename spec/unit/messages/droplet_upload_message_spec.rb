require 'spec_helper'
require 'messages/droplet_upload_message'

module VCAP::CloudController
  RSpec.describe DropletUploadMessage do
    before { TestConfig.override(directories: { tmpdir: '/tmp/' }) }

    describe 'validations' do
      let(:stat_double) { instance_double(File::Stat, size: 2) }
      before do
        allow(File).to receive(:stat).and_return(stat_double)
      end

      context 'when the <ngnix_upload_module_dummy> param is set' do
        let(:opts) { { '<ngx_upload_module_dummy>' => '', bits_path: '/tmp/foobar', bits_name: 'droplet.tgz' } }

        it 'is invalid' do
          upload_message = DropletUploadMessage.new(opts)
          expect(upload_message).not_to be_valid
          expect(upload_message.errors[:base]).to include('Uploaded bits are not a valid droplet file')
        end
      end

      context 'when the path and name are provided correctly' do
        let(:opts) { { bits_path: '/tmp/foobar', bits_name: 'droplet.tgz' } }

        it 'is valid' do
          upload_message = DropletUploadMessage.new(opts)
          expect(upload_message).to be_valid
        end
      end

      context 'when the path is relative' do
        let(:opts) { { bits_path: '../tmp/mango/pear', bits_name: 'droplet.tgz' } }

        it 'is valid' do
          upload_message = DropletUploadMessage.new(opts)
          expect(upload_message).to be_valid
        end
      end

      context 'when the path is relative but matches a prefix of the base dir' do
        let(:opts) { { bits_path: '../tmp-not!/mango/pear' } }

        it 'is not valid' do
          upload_message = DropletUploadMessage.new(opts)
          expect(upload_message).not_to be_valid
          expect(upload_message.errors[:bits_path]).to include('is invalid')
        end
      end

      context 'when the path is not provided' do
        let(:opts) { {} }
        it 'is not valid' do
          upload_message = DropletUploadMessage.new(opts)
          expect(upload_message).not_to be_valid
          expect(upload_message.errors[:base]).to include('A droplet tgz file must be uploaded as \'bits\'')
        end
      end

      context 'when unexpected keys are requested' do
        let(:opts) { { bits_path: '/tmp/bar', unexpected: 'foo' } }

        it 'is not valid' do
          message = DropletUploadMessage.new(opts)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
        end
      end

      context 'when the bits_path is not within the tmpdir' do
        let(:opts) { { bits_path: '/secret/file', bits_name: 'droplet.tgz' } }

        it 'is not valid' do
          message = DropletUploadMessage.new(opts)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include('Bits path is invalid')
        end
      end

      context 'when the bits name is not provided' do
        let(:opts) { { bits_path: '/tmp/bar' } }

        it ' is not valid' do
          upload_message = DropletUploadMessage.new(opts)
          expect(upload_message).not_to be_valid
          expect(upload_message.errors[:base]).to include('A droplet tgz file must be uploaded as \'bits\'')
        end
      end

      context 'when the file is a .tar.gz' do
        let(:opts) { { bits_path: '/tmp/bar', bits_name: 'droplet.tar.gz' } }

        it ' is not valid' do
          upload_message = DropletUploadMessage.new(opts)
          expect(upload_message).to be_valid
        end
      end

      context 'when the file is not a tgz or tar.gz' do
        let(:opts) { { bits_path: '/tmp/bar', bits_name: 'droplet.zip' } }

        it ' is not valid' do
          upload_message = DropletUploadMessage.new(opts)
          expect(upload_message).not_to be_valid
          expect(upload_message.errors.full_messages[0]).to include('droplet.zip is not a tgz')
        end
      end

      context 'when the file is empty' do
        let(:opts) { { bits_path: '/tmp/bar', bits_name: 'droplet.tgz' } }
        let(:stat_double) { instance_double(File::Stat, size: 0) }

        it 'is not valid' do
          upload_message = DropletUploadMessage.new(opts)
          expect(upload_message).not_to be_valid
          expect(upload_message.errors.full_messages[0]).to include('droplet.tgz cannot be empty')
        end
      end
    end

    describe '#bits_path=' do
      subject(:upload_message) { DropletUploadMessage.new(bits_path: 'not-nil') }

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
      let(:params) { { 'bits_path' => '/tmp/foobar', 'bits_name' => 'droplet.tgz' } }

      it 'returns the correct DropletUploadMessage' do
        message = DropletUploadMessage.create_from_params(params)

        expect(message).to be_a(DropletUploadMessage)
        expect(message.bits_path).to eq('/tmp/foobar')
        expect(message.bits_name).to eq('droplet.tgz')
      end

      it 'converts requested keys to symbols' do
        message = DropletUploadMessage.create_from_params(params)

        expect(message.requested?(:bits_path)).to be_truthy
        expect(message.requested?(:bits_name)).to be_truthy
      end
    end
  end
end
