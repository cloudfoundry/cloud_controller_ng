require 'spec_helper'
require 'messages/process_scale_message'

module VCAP::CloudController
  RSpec.describe ManifestProcessScaleMessage do
    describe 'validations' do
      context 'when unexpected keys are requested' do
        let(:params) { { instances: 3, memory: 6, memory_in_mb: 2048 } }

        it 'is not valid' do
          message = ManifestProcessScaleMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.full_messages[0]).to include("Unknown field(s): 'memory_in_mb'")
        end
      end

      describe '#instances' do
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
      end

      describe '#memory' do
        context 'when memory is not a number' do
          let(:params) { { memory: 'silly string thing' } }

          it 'is not valid' do
            message = ManifestProcessScaleMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.count).to eq(1)
            expect(message.errors.full_messages).to include('Memory must be greater than 0MB')
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
            expect(message.errors.full_messages).to include('Memory must be greater than 0MB')
          end
        end
      end

      describe '#disk_quota' do
        context 'when disk_quota is not an number' do
          let(:params) { { disk_quota: 'silly string thing' } }

          it 'is not valid' do
            message = ManifestProcessScaleMessage.new(params)

            expect(message).not_to be_valid
            expect(message.errors.count).to eq(1)
            expect(message.errors.full_messages).to include('Disk quota must be greater than 0MB')
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
            expect(message.errors.full_messages).to include('Disk quota must be greater than 0MB')
          end
        end
      end

      context 'when we have more than one error' do
        let(:params) { { disk_quota: 3.5, memory: 'smiling greg' } }

        it 'is not valid' do
          message = ManifestProcessScaleMessage.new(params)

          expect(message).not_to be_valid
          expect(message.errors.count).to eq(2)
          expect(message.errors.full_messages).to match_array([
            'Disk quota must be greater than 0MB',
            'Memory must be greater than 0MB'
          ])
        end
      end
    end

    describe '#to_process_scale_message' do
      let(:manifest_message) { ManifestProcessScaleMessage.new(params) }

      context 'when all params are given' do
        let(:params) { { instances: 3, memory: 1024, disk_quota: 2048 } }

        it 'returns a process_scale_message with the appropriate values' do
          scale_message = manifest_message.to_process_scale_message

          expect(scale_message.instances).to eq(3)
          expect(scale_message.memory_in_mb).to eq(1024)
          expect(scale_message.disk_in_mb).to eq(2048)
        end
      end

      context 'when no disk_quota is given' do
        let(:params) { { instances: 3, memory: 1024 } }

        it 'does not set anything for disk_in_mb' do
          scale_message = manifest_message.to_process_scale_message

          expect(scale_message.instances).to eq(3)
          expect(scale_message.memory_in_mb).to eq(1024)
          expect(scale_message.disk_in_mb).to be_falsey
        end
      end

      context 'when no instances is given' do
        let(:params) { { memory: 1024, disk_quota: 2048 } }

        it 'does not set anything for instances' do
          scale_message = manifest_message.to_process_scale_message

          expect(scale_message.instances).to be_falsey
          expect(scale_message.memory_in_mb).to eq(1024)
          expect(scale_message.disk_in_mb).to eq(2048)
        end
      end

      context 'when no memory is given' do
        let(:params) { { instances: 3, disk_quota: 2048 } }

        it 'does not set anything for memory_in_mb' do
          scale_message = manifest_message.to_process_scale_message

          expect(scale_message.instances).to eq(3)
          expect(scale_message.memory_in_mb).to be_falsey
          expect(scale_message.disk_in_mb).to eq(2048)
        end
      end
    end
  end
end
