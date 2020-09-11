require 'spec_helper'
require 'messages/process_scale_message'
require 'messages/base_message'

module VCAP::CloudController
  RSpec.describe ProcessScaleMessage do
    context 'when unexpected keys are requested' do
      let(:params) { { instances: 3, memory_in_mb: 2048, unexpected: 'foo' } }

      it 'is not valid' do
        message = ProcessScaleMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
      end
    end

    context 'when instances is not an number' do
      let(:params) { { instances: 'silly string thing' } }

      it 'is not valid' do
        message = ProcessScaleMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.count).to eq(1)
        expect(message.errors[:instances]).to include('is not a number')
      end
    end

    context 'when instances is not an integer' do
      let(:params) { { instances: 3.5 } }

      it 'is not valid' do
        message = ProcessScaleMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.count).to eq(1)
        expect(message.errors[:instances]).to include('must be an integer')
      end
    end

    context 'when instances is not a positive integer' do
      let(:params) { { instances: -1 } }

      it 'is not valid' do
        message = ProcessScaleMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.count).to eq(1)
        expect(message.errors[:instances]).to include('must be greater than or equal to 0')
      end
    end

    context 'when instances is > the max value allowed in the database' do
      let(:params) { { instances: BaseMessage::MAX_DB_INT + 1 } }

      it 'is not valid' do
        message = ProcessScaleMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.count).to eq(1)
        expect(message.errors[:instances]).to include('must be less than or equal to 2147483647')
      end
    end

    context 'when memory_in_mb is not an number' do
      let(:params) { { memory_in_mb: 'silly string thing' } }

      it 'is not valid' do
        message = ProcessScaleMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.count).to eq(1)
        expect(message.errors[:memory_in_mb]).to include('is not a number')
      end
    end

    context 'when memory_in_mb is < 1' do
      let(:params) { { memory_in_mb: 0 } }

      it 'is not valid' do
        message = ProcessScaleMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.count).to eq(1)
        expect(message.errors[:memory_in_mb]).to include('must be greater than 0')
      end
    end

    context 'when memory_in_mb is > the max value allowed in the database' do
      let(:params) { { memory_in_mb: BaseMessage::MAX_DB_INT + 1 } }

      it 'is not valid' do
        message = ProcessScaleMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.count).to eq(1)
        expect(message.errors[:memory_in_mb]).to include('must be less than or equal to 2147483647')
      end
    end

    context 'when memory_in_mb is not an integer' do
      let(:params) { { memory_in_mb: 3.5 } }

      it 'is not valid' do
        message = ProcessScaleMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.count).to eq(1)
        expect(message.errors[:memory_in_mb]).to include('must be an integer')
      end
    end

    context 'when disk_in_mb is not an number' do
      let(:params) { { disk_in_mb: 'silly string thing' } }

      it 'is not valid' do
        message = ProcessScaleMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.count).to eq(1)
        expect(message.errors[:disk_in_mb]).to include('is not a number')
      end
    end

    context 'when disk_in_mb is < 1' do
      let(:params) { { disk_in_mb: 0 } }

      it 'is not valid' do
        message = ProcessScaleMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.count).to eq(1)
        expect(message.errors[:disk_in_mb]).to include('must be greater than 0')
      end
    end

    context 'when disk_in_mb is > the max value allowed in the database' do
      let(:params) { { disk_in_mb: BaseMessage::MAX_DB_INT + 1 } }

      it 'is not valid' do
        message = ProcessScaleMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.count).to eq(1)
        expect(message.errors[:disk_in_mb]).to include('must be less than or equal to 2147483647')
      end
    end

    context 'when disk_in_mb is not an integer' do
      let(:params) { { disk_in_mb: 3.5 } }

      it 'is not valid' do
        message = ProcessScaleMessage.new(params)

        expect(message).not_to be_valid
        expect(message.errors.count).to eq(1)
        expect(message.errors[:disk_in_mb]).to include('must be an integer')
      end
    end
  end
end
