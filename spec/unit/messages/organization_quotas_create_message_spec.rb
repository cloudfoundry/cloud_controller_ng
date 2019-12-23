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

      describe 'apps' do
        context 'invalid keys are passed in' do
          let(:params) {
            {
              name: 'my-name',
              apps: { bad_key: 'bob' },
            }
          }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors.full_messages[0]).to include("Unknown field(s): 'bad_key'")
          end
        end

        describe 'total_memory_in_mb' do
          context 'when the type is a string' do
            let(:params) {
              {
                name: 'my-name',
                apps: { total_memory_in_mb: 'bob' },
              relationships: relationships,
            }
            }

            it 'is not valid' do
              expect(subject).to be_invalid
              p subject.errors
              expect(subject.errors[:apps]).to contain_exactly('Total memory in mb is not a number')
            end
          end
          context 'when the type is decimal' do
            let(:params) {
              {
                name: 'my-name',
                apps: { total_memory_in_mb: 1.1 },
              relationships: relationships,
            }
            }

            it 'is not valid' do
              expect(subject).to be_invalid
              expect(subject.errors[:apps]).to contain_exactly('Total memory in mb must be an integer')
            end
          end
          context 'when the type is a negative integer' do
            let(:params) {
              {
                name: 'my-name',
                apps: { total_memory_in_mb: -1 },
              relationships: relationships,
            }
            }

            it 'is not valid because "unlimited" is set with null, not -1, in V3' do
              expect(subject).to be_invalid
              expect(subject.errors[:apps]).to contain_exactly('Total memory in mb must be greater than or equal to 0')
            end
          end

          context 'when the type is zero' do
            let(:params) {
              {
                name: 'my-name',
                apps: { total_memory_in_mb: 0 },
              relationships: relationships,
            }
            }

            it { is_expected.to be_valid }
          end
          context 'when the type is nil (unlimited)' do
            let(:params) {
              {
                name: 'my-name',
                apps: { total_memory_in_mb: nil },
              relationships: relationships,
            }
            }

            it { is_expected.to be_valid }
          end
        end

        describe 'per_process_memory_in_mb' do
          context 'when the type is a string' do
            let(:params) {
              {
                name: 'my-name',
                apps: { per_process_memory_in_mb: 'bob' },
              relationships: relationships,
            }
            }

            it 'is not valid' do
              expect(subject).to be_invalid
              p subject.errors
              expect(subject.errors[:apps]).to contain_exactly('Per process memory in mb is not a number')
            end
          end
          context 'when the type is decimal' do
            let(:params) {
              {
                name: 'my-name',
                apps: { per_process_memory_in_mb: 1.1 },
              relationships: relationships,
            }
            }

            it 'is not valid' do
              expect(subject).to be_invalid
              expect(subject.errors[:apps]).to contain_exactly('Per process memory in mb must be an integer')
            end
          end
          context 'when the type is a negative integer' do
            let(:params) {
              {
                name: 'my-name',
                apps: { per_process_memory_in_mb: -1 },
              relationships: relationships,
            }
            }

            it 'is not valid because "unlimited" is set with null, not -1, in V3' do
              expect(subject).to be_invalid
              expect(subject.errors[:apps]).to contain_exactly('Per process memory in mb must be greater than or equal to 0')
            end
          end

          context 'when the type is zero' do
            let(:params) {
              {
                name: 'my-name',
                apps: { per_process_memory_in_mb: 0 },
              relationships: relationships,
            }
            }

            it { is_expected.to be_valid }
          end
          context 'when the type is nil (unlimited)' do
            let(:params) {
              {
                name: 'my-name',
                apps: { per_process_memory_in_mb: nil },
              relationships: relationships,
            }
            }

            it { is_expected.to be_valid }
          end
        end

        describe 'total_instances' do
          context 'when the type is a string' do
            let(:params) {
              {
                name: 'my-name',
                apps: { total_instances: 'bob' },
              relationships: relationships,
            }
            }

            it 'is not valid' do
              expect(subject).to be_invalid
              p subject.errors
              expect(subject.errors[:apps]).to contain_exactly('Total instances is not a number')
            end
          end
          context 'when the type is decimal' do
            let(:params) {
              {
                name: 'my-name',
                apps: { total_instances: 1.1 },
              relationships: relationships,
            }
            }

            it 'is not valid' do
              expect(subject).to be_invalid
              expect(subject.errors[:apps]).to contain_exactly('Total instances must be an integer')
            end
          end
          context 'when the type is a negative integer' do
            let(:params) {
              {
                name: 'my-name',
                apps: { total_instances: -1 },
              relationships: relationships,
            }
            }

            it 'is not valid because "unlimited" is set with null, not -1, in V3' do
              expect(subject).to be_invalid
              expect(subject.errors[:apps]).to contain_exactly('Total instances must be greater than or equal to 0')
            end
          end

          context 'when the type is zero' do
            let(:params) {
              {
                name: 'my-name',
                apps: { total_instances: 0 },
              relationships: relationships,
            }
            }

            it { is_expected.to be_valid }
          end
          context 'when the type is nil (unlimited)' do
            let(:params) {
              {
                name: 'my-name',
                apps: { total_instances: nil },
              relationships: relationships,
            }
            }

            it { is_expected.to be_valid }
          end
        end

        describe 'per_app_tasks' do
          context 'when the type is a string' do
            let(:params) {
              {
                name: 'my-name',
                apps: { per_app_tasks: 'bob' },
              }
            }

            it 'is not valid' do
              expect(subject).to be_invalid
              p subject.errors
              expect(subject.errors[:apps]).to contain_exactly('Per app tasks is not a number')
            end
          end
          context 'when the type is decimal' do
            let(:params) {
              {
                name: 'my-name',
                apps: { per_app_tasks: 1.1 },
              }
            }

            it 'is not valid' do
              expect(subject).to be_invalid
              expect(subject.errors[:apps]).to contain_exactly('Per app tasks must be an integer')
            end
          end
          context 'when the type is a negative integer' do
            let(:params) {
              {
                name: 'my-name',
                apps: { per_app_tasks: -1 },
              }
            }

            it 'is not valid because "unlimited" is set with null, not -1, in V3' do
              expect(subject).to be_invalid
              expect(subject.errors[:apps]).to contain_exactly('Per app tasks must be greater than or equal to 0')
            end
          end

          context 'when the type is zero' do
            let(:params) {
              {
                name: 'my-name',
                apps: { per_app_tasks: 0 },
              }
            }

            it { is_expected.to be_valid }
          end
          context 'when the type is nil (unlimited)' do
            let(:params) {
              {
                name: 'my-name',
                apps: { per_app_tasks: nil },
              }
            }

            it { is_expected.to be_valid }
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
