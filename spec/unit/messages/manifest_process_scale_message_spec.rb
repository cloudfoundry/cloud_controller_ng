require 'spec_helper'
require 'messages/process_scale_message'

module VCAP::CloudController
  RSpec.describe ManifestProcessScaleMessage do
    context 'when unexpected keys are requested' do
      let(:params) { { instances: 3, memory: 6, memory_in_mb: 2048 } } # memory_in_mb is unexpected unlike ProcessScaleMessage

      it 'is not valid' do
        message = ManifestProcessScaleMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.full_messages[0]).to include("Unknown field(s): 'memory_in_mb'")
      end
    end

    context 'when instances is not an number' do
      let(:params) { { instances: 'silly string thing' } }

      it 'is not valid' do
        message = ManifestProcessScaleMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.count).to eq(1)
        expect(message.errors[:instances]).to include('is not a number')
      end
    end

    context 'when instances is not an integer' do
      let(:params) { { instances: 3.5 } }

      it 'is not valid' do
        message = ManifestProcessScaleMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.count).to eq(1)
        expect(message.errors[:instances]).to include('must be an integer')
      end
    end

    context 'when instances is not a positive integer' do
      let(:params) { { instances: -1 } }

      it 'is not valid' do
        message = ManifestProcessScaleMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.count).to eq(1)
        expect(message.errors[:instances]).to include('must be greater than or equal to 0')
      end
    end

    context 'when memory is not a number' do
      let(:params) { { memory: 'silly string thing' } }

      it 'is not valid' do
        message = ManifestProcessScaleMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.count).to eq(1)
        expect(message.errors.full_messages).to include('Memory is not a number')
      end
    end

    context 'when memory is < 1' do
      let(:params) { { memory: 0 } }

      it 'is not valid' do
        message = ManifestProcessScaleMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.count).to eq(1)
        expect(message.errors.full_messages).to include('Memory must be greater than 0MB')
      end
    end

    context 'when memory is not an integer' do
      let(:params) { { memory: 3.5 } }

      it 'is not valid' do
        message = ManifestProcessScaleMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.count).to eq(1)
        expect(message.errors.full_messages).to include('Memory must be an integer')
      end

      context 'when disk_quota is not an number' do
        let(:params) { { disk_quota: 'silly string thing' } }

        it 'is not valid' do
          message = ManifestProcessScaleMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.count).to eq(1)
          expect(message.errors.full_messages).to include('Disk quota is not a number')
        end
      end

      context 'when disk_quota is < 1' do
        let(:params) { { disk_quota: 0 } }

        it 'is not valid' do
          message = ManifestProcessScaleMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.count).to eq(1)
          expect(message.errors.full_messages).to include('Disk quota must be greater than 0MB')
        end
      end

      context 'when disk_quota is not an integer' do
        let(:params) { { disk_quota: 3.5 } }

        it 'is not valid' do
          message = ManifestProcessScaleMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.count).to eq(1)
          expect(message.errors.full_messages).to include('Disk quota must be an integer')
        end
      end
    end

    describe '.create_from_http_request' do
      let(:body) { { 'instances' => 3, 'disk_quota' => 2048, 'memory' => 1025.0 } }

      it 'returns a ManifestProcessScaleMessage' do
        message = ManifestProcessScaleMessage.create_from_http_request(body)

        expect(message).to be_a(ManifestProcessScaleMessage)
        expect(message.errors).to be_empty
        expect(message.memory).to eq(1025)
        expect(message.disk_quota).to eq(2048)
        expect(message.instances).to eq(3)
      end

      it 'converts requested keys to symbols' do
        message = ManifestProcessScaleMessage.create_from_http_request(body)

        expect(message.requested?(:instances)).to be_truthy
      end
    end

    describe 'invalid_field_message_with_nil_object' do
      let(:data) do { value: value } end
      let(:result) { ManifestProcessScaleMessage.invalid_field_message_with_nil_object(data) }

      context "when it's not a number" do
        let(:value) { 'size-50 natty bo T-shirt' }
        it 'is not a number' do
          expect(result).to eq('is not a number')
        end
      end

      context "when it's not an integer" do
        let(:value) { '22.4' }
        it 'is not a float' do
          expect(result).to eq('must be an integer')
        end
      end

      context "when it's negative" do
        let(:value) { -22 }
        it 'is negative' do
          expect(result).to eq('must be greater than 0MB')
        end
      end
    end
  end
end
