require 'spec_helper'
require 'messages/space_quotas_create_message'

module VCAP::CloudController
  RSpec.describe SpaceQuotasCreateMessage do
    subject { SpaceQuotasCreateMessage.new(params) }
    let(:relationships) do
      {
        organization: {
          data: {
            guid: 'some-org-guid'
          }
        },
      }
    end

    describe 'validations' do
      context 'when no params are given' do
        let(:params) {}

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors[:name]).to eq ['must be a string', "can't be blank"]
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
          let(:params) { { name: 'thë-name', relationships: relationships } }

          it { is_expected.to be_valid }
        end

        context 'when it contains hyphens' do
          let(:params) { { name: 'a-z', relationships: relationships } }

          it { is_expected.to be_valid }
        end

        context 'when it contains capital ascii' do
          let(:params) { { name: 'AZ', relationships: relationships } }

          it { is_expected.to be_valid }
        end

        context 'when it is at max length' do
          let(:params) { { name: 'B' * SpaceQuotasCreateMessage::MAX_SPACE_QUOTA_NAME_LENGTH, relationships: relationships } }

          it { is_expected.to be_valid }
        end

        context 'when it is too long' do
          let(:params) { { name: 'B' * (SpaceQuotasCreateMessage::MAX_SPACE_QUOTA_NAME_LENGTH + 1), relationships: relationships } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:name]).to contain_exactly('is too long (maximum is 250 characters)')
          end
        end

        context 'when it is blank' do
          let(:params) { { name: '', relationships: relationships } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:name]).to eq ["can't be blank"]
          end
        end
      end

      describe 'relationships' do
        context 'given no organization guid' do
          let(:params) do
            {
              name: 'kris',
            }
          end

          it { is_expected.to be_invalid }
        end

        context 'given unexpected relationship data (not one-to-one relationship)' do
          let(:params) do
            {
              name: 'kim',
              relationships: {
                organization: {
                  data: [
                    { guid: 'KKW-beauty' },
                    { guid: 'skims' },
                  ]
                },
              }
            }
          end

          it { is_expected.to be_invalid }
        end

        context 'given a malformed organization guid' do
          let(:params) do
            {
              name: 'rob',
              relationships: {
                organizations: {
                  data: {
                    guid: 150000
                  },
                }
              }
            }
          end

          it { is_expected.to be_invalid }
        end
      end
    end
  end
end
