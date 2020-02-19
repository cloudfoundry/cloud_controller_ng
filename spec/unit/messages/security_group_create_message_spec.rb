require 'spec_helper'
require 'messages/organization_quotas_create_message'

module VCAP::CloudController
  RSpec.describe SecurityGroupCreateMessage do
    subject { SecurityGroupCreateMessage.new(params) }

    describe 'validations' do
      context 'when no params are given' do
        let(:params) {}

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors[:name]).to eq ["can't be blank"]
        end
      end

      context 'when unexpected keys are requested' do
        let(:params) { { unexpected: 'meow', name: 'the-name' } }

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors.full_messages[0]).to include("Unknown field(s): 'unexpected'")
        end
      end

      describe 'name' do
        context 'when it is non-alphanumeric' do
          let(:params) { { name: 'thë-name' } }

          it { is_expected.to be_valid }
        end

        context 'when it contains hyphens' do
          let(:params) { { name: 'a-z' } }

          it { is_expected.to be_valid }
        end

        context 'when it contains capital ascii' do
          let(:params) { { name: 'AZ' } }

          it { is_expected.to be_valid }
        end

        context 'when it is at max length' do
          let(:params) { { name: 'B' * SecurityGroupCreateMessage::MAX_SECURITY_GROUP_NAME_LENGTH } }

          it { is_expected.to be_valid }
        end

        context 'when it is too long' do
          let(:params) { { name: 'B' * (SecurityGroupCreateMessage::MAX_SECURITY_GROUP_NAME_LENGTH + 1), } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:name]).to contain_exactly('is too long (maximum is 250 characters)')
          end
        end

        context 'when it is blank' do
          let(:params) { { name: '' } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:name]).to include("can't be blank")
          end
        end

        context 'params' do
          let(:rules) { [] }

          let(:params) do
            {
              name: 'basic',
              rules: rules,
            }
          end

          context 'when no rules are passed in' do
            let(:params) do
              { name: 'no_rules' }
            end
            it 'is valid' do
              expect(subject).to be_valid
            end
          end

          context 'when an empty set of rules is passed in' do
            it 'is valid' do
              expect(subject).to be_valid
            end
          end

          context 'when a malformed set of rules is passed in' do
            let(:rules) { 'bad rule' }
            # it is invalid
            it 'is valid' do
              expect(subject).to be_invalid
            end
          end
        end
      end

      describe 'rules' do
        let(:rules) { [] }

        let(:params) do
          {
            name: 'basic',
            rules: rules,
          }
        end

        context 'when no rules are passed in' do
          let(:params) do
            { name: 'no_rules' }
          end
          it 'is valid' do
            expect(subject).to be_valid
          end
        end

        context 'when an empty set of rules is passed in' do
          it 'is valid' do
            expect(subject).to be_valid
          end
        end

        context 'when a malformed set of rules is passed in' do
          let(:rules) { 'bad rule' }
          # it is invalid
          it 'is valid' do
            expect(subject).to be_invalid
          end
        end
      end
    end
  end
end
