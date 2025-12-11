require 'spec_helper'
require 'messages/stack_create_message'

RSpec.describe VCAP::CloudController::StackCreateMessage do
  describe 'validations' do
    subject { described_class.new(params) }

    let(:valid_params) do
      {
        name: 'reasonable-name',
        metadata: {
          labels: {
            potato: 'mashed'
          },
          annotations: {
            happy: 'annotation'
          }
        }
      }
    end

    it 'is valid if using the valid parameters' do
      expect(described_class.new(valid_params)).to be_valid
    end

    describe 'name' do
      MAX_NAME_LENGTH = 250
      MAX_DESCRIPTION_LENGTH = 250

      context 'when it is not provided' do
        let(:params) { valid_params.except(:name) }

        it 'returns an error' do
          expect(subject).not_to be_valid
          expect(subject.errors[:name]).to eq ["can't be blank"]
        end
      end

      context 'when it is 0 characters long' do
        let(:params) { valid_params.merge({ name: '' }) }

        it 'returns an error' do
          expect(subject).not_to be_valid
          expect(subject.errors[:name]).to eq ["can't be blank"]
        end
      end

      context 'when it is just long enough' do
        let(:params) { { name: 'A' * MAX_NAME_LENGTH } }

        it 'is valid' do
          expect(subject).to be_valid
        end
      end

      context 'when it is too long' do
        let(:params) { valid_params.merge({ name: 'A' * (MAX_NAME_LENGTH + 1) }) }

        it 'returns an error' do
          expect(subject).not_to be_valid
          expect(subject.errors[:name]).to eq ["is too long (maximum is #{MAX_NAME_LENGTH} characters)"]
        end
      end
    end

    describe 'description' do
      context 'when it is just long enough' do
        let(:params) { valid_params.merge({ description: 'A' * MAX_DESCRIPTION_LENGTH }) }

        it 'is valid' do
          expect(subject).to be_valid
        end
      end

      context 'when it is too long' do
        let(:params) { valid_params.merge({ description: 'A' * (MAX_DESCRIPTION_LENGTH + 1) }) }

        it 'returns an error' do
          expect(subject).not_to be_valid
          expect(subject.errors[:description]).to eq ["is too long (maximum is #{MAX_DESCRIPTION_LENGTH} characters)"]
        end
      end
    end

    describe 'state' do
      context 'when it is not provided' do
        let(:params) { valid_params }

        it 'defaults to ACTIVE' do
          expect(subject.state).to eq('ACTIVE')
        end
      end

      context 'when it is a valid state' do
        %w[ACTIVE DEPRECATED RESTRICTED DISABLED].each do |valid_state|
          context "when state is #{valid_state}" do
            let(:params) { valid_params.merge({ state: valid_state }) }

            it 'is valid' do
              expect(subject).to be_valid
              expect(subject.state).to eq(valid_state)
            end
          end
        end
      end

      context 'when it is an invalid state' do
        let(:params) { valid_params.merge({ state: 'INVALID_STATE' }) }

        it 'returns an error' do
          expect(subject).not_to be_valid
          expect(subject.errors[:state]).to include('must be one of ACTIVE, RESTRICTED, DEPRECATED, DISABLED')
        end
      end

      context 'when it is explicitly null' do
        let(:params) { valid_params.merge({ state: nil }) }

        it 'returns an error' do
          expect(subject).not_to be_valid
          expect(subject.errors[:state]).to include('must be one of ACTIVE, RESTRICTED, DEPRECATED, DISABLED')
        end
      end
    end
  end
end
