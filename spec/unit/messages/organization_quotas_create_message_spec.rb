require 'spec_helper'
require 'messages/organization_quotas_create_message'

module VCAP::CloudController
  RSpec.describe OrganizationQuotasCreateMessage do
    subject { OrganizationQuotasCreateMessage.new(params) }
    let(:relationships) do
      {
        organizations: {
          data: []
        },
      }
    end

    describe 'validations' do
      context 'when no params are given' do
        let(:params) {}

        it 'is not valid' do
          expect(subject).not_to be_valid
          expect(subject.errors[:name]).to include("can't be blank")
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
          let(:params) { { name: 'B' * OrganizationQuotasCreateMessage::MAX_ORGANIZATION_QUOTA_NAME_LENGTH, relationships: relationships } }

          it { is_expected.to be_valid }
        end

        context 'when it is too long' do
          let(:params) { { name: 'B' * (OrganizationQuotasCreateMessage::MAX_ORGANIZATION_QUOTA_NAME_LENGTH + 1), relationships: relationships } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:name]).to contain_exactly('is too long (maximum is 250 characters)')
          end
        end
      end

      describe 'total_memory_in_mb' do
        context 'when the type is a string' do
          let(:params) {
            {
              name: 'my-name',
              total_memory_in_mb: 'bob',
              relationships: relationships,
            }
          }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:total_memory_in_mb]).to contain_exactly('is not a number')
          end
        end
        context 'when the type is decimal' do
          let(:params) {
            {
              name: 'my-name',
              total_memory_in_mb: 1.1,
              relationships: relationships,
            }
          }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:total_memory_in_mb]).to contain_exactly('must be an integer')
          end
        end
        context 'when the type is a negative integer' do
          let(:params) {
            {
              name: 'my-name',
              total_memory_in_mb: -1,
              relationships: relationships,
            }
          }

          it 'is not valid because "unlimited" is set with null, not -1, in V3' do
            expect(subject).to be_invalid
            expect(subject.errors[:total_memory_in_mb]).to contain_exactly('must be greater than or equal to 0')
          end
        end
        context 'when the type is zero' do
          let(:params) {
            {
              name: 'my-name',
              total_memory_in_mb: 0,
              relationships: relationships,
            }
          }

          it { is_expected.to be_valid }
        end
        context 'when the type is nil (unlimited)' do
          let(:params) {
            {
              name: 'my-name',
              total_memory_in_mb: nil,
              relationships: relationships,
            }
          }

          it { is_expected.to be_valid }
        end
      end

      describe 'total_service_instances' do
        context 'when the type is a string' do
          let(:params) {
            {
              name: 'my-name',
              total_service_instances: 'bob',
              relationships: relationships,
            }
          }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:total_service_instances]).to contain_exactly('is not a number')
          end
        end
        context 'when the type is decimal' do
          let(:params) {
            {
              name: 'my-name',
              total_service_instances: 1.1,
              relationships: relationships,
            }
          }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:total_service_instances]).to contain_exactly('must be an integer')
          end
        end
        context 'when the type is a negative integer' do
          let(:params) {
            {
              name: 'my-name',
              total_service_instances: -1,
              relationships: relationships,
            }
          }

          it 'is not valid because "unlimited" is set with null, not -1, in V3' do
            expect(subject).to be_invalid
            expect(subject.errors[:total_service_instances]).to contain_exactly('must be greater than or equal to 0')
          end
        end
        context 'when the type is zero' do
          let(:params) {
            {
              name: 'my-name',
              total_service_instances: 0,
              relationships: relationships,
            }
          }

          it { is_expected.to be_valid }
        end
        context 'when the type is nil (unlimited)' do
          let(:params) {
            {
              name: 'my-name',
              total_service_instances: nil,
              relationships: relationships,
            }
          }

          it { is_expected.to be_valid }
        end
      end

      describe 'total_routes' do
        context 'when the type is a string' do
          let(:params) {
            {
              name: 'my-name',
              total_routes: 'bob',
              relationships: relationships,
            }
          }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:total_routes]).to contain_exactly('is not a number')
          end
        end
        context 'when the type is decimal' do
          let(:params) {
            {
              name: 'my-name',
              total_routes: 1.1,
              relationships: relationships,
            }
          }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:total_routes]).to contain_exactly('must be an integer')
          end
        end
        context 'when the type is a negative integer' do
          let(:params) {
            {
              name: 'my-name',
              total_routes: -1,
              relationships: relationships,
            }
          }

          it 'is not valid because "unlimited" is set with null, not -1, in V3' do
            expect(subject).to be_invalid
            expect(subject.errors[:total_routes]).to contain_exactly('must be greater than or equal to 0')
          end
        end
        context 'when the type is zero' do
          let(:params) {
            {
              name: 'my-name',
              total_routes: 0,
              relationships: relationships,
            }
          }

          it { is_expected.to be_valid }
        end
        context 'when the type is nil (unlimited)' do
          let(:params) {
            {
              name: 'my-name',
              total_routes: nil,
              relationships: relationships,
            }
          }

          it { is_expected.to be_valid }
        end
      end

      describe 'paid_services_allowed' do
        context 'when it is a boolean' do
          let(:params) {
            {
              name: 'thë-name',
              paid_services_allowed: false,
              relationships: relationships,
            }
          }

          it { is_expected.to be_valid }
        end

        context 'when it is not a boolean' do
          let(:params) {
            {
              name: 'thë-name',
              paid_services_allowed: 'b',
              relationships: relationships,
            }
          }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:paid_services_allowed]).to contain_exactly('must be a boolean')
          end
        end
      end

      describe 'relationships' do
        context 'given no organization guids' do
          let(:params) do
            {
              name: 'kris',
            }
          end

          it { is_expected.to be_valid }
        end

        context 'given mulitple organization guids' do
          let(:params) do
            {
              name: 'kim',
              relationships: {
                organizations: {
                  data: [
                    { guid: 'KKW-beauty' },
                    { guid: 'skims' },
                  ]
                },
              }
            }
          end

          it { is_expected.to be_valid }
        end

        context 'given malformed data array' do
          let(:params) do
            {
              name: 'kourtney',
              relationships: {
                organizations: { guid: 'poosh' },
              }
            }
          end

          it { is_expected.to be_invalid }
        end

        context 'given malformed organization guids' do
          let(:params) do
            {
              name: 'rob',
              relationships: {
                organizations: {
                  data: [
                    { guid: 150000 },
                  ]
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
