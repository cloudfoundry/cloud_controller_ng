require 'spec_helper'
require 'messages/organization_quotas_update_message'

module VCAP::CloudController
  RSpec.describe OrganizationQuotasUpdateMessage do
    subject { OrganizationQuotasUpdateMessage.new(params) }

    describe 'validations' do
      context 'when no params are given' do
        let(:params) {}

        it 'is valid' do
          expect(subject).to be_valid
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
          let(:params) { { name: 'B' * OrganizationQuotasUpdateMessage::MAX_ORGANIZATION_QUOTA_NAME_LENGTH, } }

          it { is_expected.to be_valid }
        end

        context 'when it is too long' do
          let(:params) { { name: 'B' * (OrganizationQuotasUpdateMessage::MAX_ORGANIZATION_QUOTA_NAME_LENGTH + 1), } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:name]).to contain_exactly('is too long (maximum is 250 characters)')
          end
        end

        context 'when it is blank' do
          let(:params) { { name: '', } }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors[:name]).to eq ['is too short (minimum is 1 character)']
          end
        end
      end

      describe 'apps' do
        context 'value for apps is not a hash' do
          let(:params) {
            {
              name: 'my-name',
              apps: true,
            }
          }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors.full_messages[0]).to include('Apps must be an object')
          end
        end

        context 'when apps is well-formed (a hash)' do
          let(:params) {
            {
              name: 'my-name',
              apps: {},
            }
          }

          before do
            quota_app_message = instance_double(QuotasAppsMessage)
            allow(QuotasAppsMessage).to receive(:new).and_return(quota_app_message)
            allow(quota_app_message).to receive(:valid?).and_return(false)
            allow(quota_app_message).to receive_message_chain(:errors, :full_messages).and_return(['invalid_app_limits'])
          end

          it 'delegates validation to QuotasAppsMessage and returns any errors' do
            expect(subject).to be_invalid
            expect(subject.errors[:apps]).to include('invalid_app_limits')
          end
        end
      end

      describe 'services' do
        context 'value for services is not a hash' do
          let(:params) {
            {
              name: 'my-name',
              services: true,
            }
          }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors.full_messages[0]).to include('Services must be an object')
          end
        end

        context 'when services is well-formed (a hash)' do
          let(:params) {
            {
              name: 'my-name',
              services: {},
            }
          }

          before do
            quota_services_message = instance_double(QuotasServicesMessage)
            allow(QuotasServicesMessage).to receive(:new).and_return(quota_services_message)
            allow(quota_services_message).to receive(:valid?).and_return(false)
            allow(quota_services_message).to receive_message_chain(:errors, :full_messages).and_return(['invalid_services_limits'])
          end

          it 'delegates validation to QuotasServicesMessage and returns any errors' do
            expect(subject).to be_invalid
            expect(subject.errors[:services]).to include('invalid_services_limits')
          end
        end
      end

      describe 'routes' do
        context 'value for routes is not a hash' do
          let(:params) {
            {
              name: 'my-name',
              routes: true,
            }
          }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors.full_messages[0]).to include('Routes must be an object')
          end
        end
        context 'invalid keys are passed in' do
          let(:params) {
            {
              name: 'my-name',
              routes: { bad_key: 'billy' },
            }
          }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors.full_messages[0]).to include("Unknown field(s): 'bad_key'")
          end
        end

        describe 'total_routes' do
          context 'when the type is a string' do
            let(:params) {
              {
                name: 'my-name',
                routes: { total_routes: 'bob' },
              }
            }

            it 'is not valid' do
              expect(subject).to be_invalid
              expect(subject.errors[:routes]).to contain_exactly('Total routes is not a number')
            end
          end
          context 'when the type is decimal' do
            let(:params) {
              {
                name: 'my-name',
                routes: { total_routes: 1.1 },
              }
            }

            it 'is not valid' do
              expect(subject).to be_invalid
              expect(subject.errors[:routes]).to contain_exactly('Total routes must be an integer')
            end
          end
          context 'when the type is a negative integer' do
            let(:params) {
              {
                name: 'my-name',
                routes: { total_routes: -1 },
              }
            }

            it 'is not valid because "unlimited" is set with null, not -1, in V3' do
              expect(subject).to be_invalid
              expect(subject.errors[:routes]).to contain_exactly('Total routes must be greater than or equal to 0')
            end
          end
          context 'when the type is zero' do
            let(:params) {
              {
                name: 'my-name',
                routes: { total_routes: 0 },
              }
            }

            it { is_expected.to be_valid }
          end
          context 'when the type is nil (unlimited)' do
            let(:params) {
              {
                name: 'my-name',
                routes: { total_routes: nil },
              }
            }

            it { is_expected.to be_valid }
          end
        end

        describe 'total_reserved_ports' do
          context 'when the type is a string' do
            let(:params) {
              {
                name: 'my-name',
                routes: { total_reserved_ports: 'bob' },
              }
            }

            it 'is not valid' do
              expect(subject).to be_invalid
              expect(subject.errors[:routes]).to contain_exactly('Total reserved ports is not a number')
            end
          end
          context 'when the type is decimal' do
            let(:params) {
              {
                name: 'my-name',
                routes: { total_reserved_ports: 1.1 },
              }
            }

            it 'is not valid' do
              expect(subject).to be_invalid
              expect(subject.errors[:routes]).to contain_exactly('Total reserved ports must be an integer')
            end
          end
          context 'when the type is a negative integer' do
            let(:params) {
              {
                name: 'my-name',
                routes: { total_reserved_ports: -1 },
              }
            }

            it 'is not valid because "unlimited" is set with null, not -1, in V3' do
              expect(subject).to be_invalid
              expect(subject.errors[:routes]).to contain_exactly('Total reserved ports must be greater than or equal to 0')
            end
          end
          context 'when the type is zero' do
            let(:params) {
              {
                name: 'my-name',
                routes: { total_reserved_ports: 0 },
              }
            }

            it { is_expected.to be_valid }
          end
          context 'when the type is nil (unlimited)' do
            let(:params) {
              {
                name: 'my-name',
                routes: { total_reserved_ports: nil },
              }
            }

            it { is_expected.to be_valid }
          end
        end
      end

      describe 'domains' do
        context 'value for domains is not a hash' do
          let(:params) {
            {
              name: 'my-name',
              domains: true,
            }
          }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors.full_messages[0]).to include('Domains must be an object')
          end
        end
        context 'invalid keys are passed in' do
          let(:params) {
            {
              name: 'my-name',
              domains: { bad_key: 'billy' },
            }
          }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors.full_messages[0]).to include("Unknown field(s): 'bad_key'")
          end

          describe 'total_domains' do
            context 'when the type is a string' do
              let(:params) {
                {
                  name: 'my-name',
                  domains: { total_domains: 'bob' },
                }
              }

              it 'is not valid' do
                expect(subject).to be_invalid
                expect(subject.errors[:domains]).to contain_exactly('Total domains is not a number')
              end
            end
            context 'when the type is decimal' do
              let(:params) {
                {
                  name: 'my-name',
                  domains: { total_domains: 1.1 },
                }
              }

              it 'is not valid' do
                expect(subject).to be_invalid
                expect(subject.errors[:domains]).to contain_exactly('Total domains must be an integer')
              end
            end
            context 'when the type is a negative integer' do
              let(:params) {
                {
                  name: 'my-name',
                  domains: { total_domains: -1 },
                }
              }

              it 'is not valid because "unlimited" is set with null, not -1, in V3' do
                expect(subject).to be_invalid
                expect(subject.errors[:domains]).to contain_exactly('Total domains must be greater than or equal to 0')
              end
            end
            context 'when the type is zero' do
              let(:params) {
                {
                  name: 'my-name',
                  domains: { total_domains: 0 },
                }
              }

              it { is_expected.to be_valid }
            end
            context 'when the type is nil (unlimited)' do
              let(:params) {
                {
                  name: 'my-name',
                  domains: { total_domains: nil },
                }
              }

              it { is_expected.to be_valid }
            end
          end
        end
      end
    end
  end
end
