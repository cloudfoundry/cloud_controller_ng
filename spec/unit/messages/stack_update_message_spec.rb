require 'lightweight_spec_helper'
require 'messages/stack_update_message'

RSpec.describe VCAP::CloudController::StackUpdateMessage do
  describe 'validations' do
    subject { described_class.new(params) }

    let(:valid_params) do
      {
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

    it 'is valid with metadata only' do
      expect(described_class.new(valid_params)).to be_valid
    end

    describe 'state' do
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

      context 'when it is not provided' do
        let(:params) { valid_params }

        it 'is valid' do
          expect(subject).to be_valid
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
