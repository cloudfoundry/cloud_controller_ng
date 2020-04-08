require 'spec_helper'
require 'messages/space_quotas_create_message'

module VCAP::CloudController
  RSpec.describe SpaceQuotasCreateMessage do
    subject { SpaceQuotasCreateMessage.new(params) }

    let(:params) do
      {
        name: 'basic',
        apps: apps,
        services: services,
        routes: routes,
        relationships: relationships,
      }
    end

    let(:apps) do
      {
        total_memory_in_mb: 2048,
        per_process_memory_in_mb: 1024,
        total_instances: 2,
        per_app_tasks: 4,
      }
    end

    let(:services) do
      {
        paid_services_allowed: true,
        total_service_instances: 17,
        total_service_keys: 19,
      }
    end

    let(:routes) do
      {
        total_routes: 47,
        total_reserved_ports: 28,
      }
    end

    let(:relationships) do
      {
        organization: {
          data: {
            guid: 'some-org-guid'
          }
        },
        spaces: {
          data: [
            { guid: 'some-space-guid' }
          ]
        },
      }
    end

    context 'when given correct & well-formed params' do
      it 'successfully validates the inputs' do
        expect(subject).to be_valid
      end

      it 'populates the fields on the message' do
        expect(subject.name).to eq('basic')
        expect(subject.organization_guid).to eq('some-org-guid')
        expect(subject.space_guids).to eq(['some-space-guid'])
        expect(subject.total_memory_in_mb).to eq(2048)
        expect(subject.per_process_memory_in_mb).to eq(1024)
        expect(subject.total_instances).to eq(2)
        expect(subject.per_app_tasks).to eq(4)
        expect(subject.paid_services_allowed).to be_truthy
        expect(subject.total_service_instances).to eq(17)
        expect(subject.total_service_keys).to eq(19)
        expect(subject.total_routes).to eq(47)
        expect(subject.total_reserved_ports).to eq(28)
      end
    end

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
            expect(subject.errors[:name]).to include("can't be blank")
          end
        end
      end

      describe 'apps' do
        context 'value for apps is not a hash' do
          let(:params) {
            {
              name: 'my-name',
              relationships: relationships,
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
              relationships: relationships,
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
              relationships: relationships,
              services: true,
            }
          }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors.full_messages[0]).to include('Services must be an object')
          end
        end

        context 'when the services validator returns errors' do
          let(:params) {
            {
              name: 'my-name',
              relationships: relationships,
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
              relationships: relationships,
              routes: true,
            }
          }

          it 'is not valid' do
            expect(subject).to be_invalid
            expect(subject.errors.full_messages[0]).to include('Routes must be an object')
          end
        end

        context 'when the routes validator returns errors' do
          let(:params) {
            {
              name: 'my-name',
              relationships: relationships,
              routes: {},
            }
          }

          before do
            quota_routes_message = instance_double(QuotasRoutesMessage)
            allow(QuotasRoutesMessage).to receive(:new).and_return(quota_routes_message)
            allow(quota_routes_message).to receive(:valid?).and_return(false)
            allow(quota_routes_message).to receive_message_chain(:errors, :full_messages).and_return(['invalid_routes_limits'])
          end

          it 'delegates validation to QuotasRoutesMessage and returns any errors' do
            expect(subject).to be_invalid
            expect(subject.errors[:routes]).to include('invalid_routes_limits')
          end
        end
      end

      describe 'relationships' do
        context 'given no relationships' do
          let(:params) do
            {
              name: 'kris',
            }
          end

          it { is_expected.to be_invalid }
        end

        context 'given unexpected org relationship data (not one-to-one relationship)' do
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

        context 'given unexpected spaces relationship data (not one-to-many relationship)' do
          let(:params) do
            {
              name: 'kim',
              relationships: {
                organization: {
                  data: { guid: 'KKW-beauty' }
                },
                spaces: {
                  data: { guid: 'skims' }
                }
              }
            }
          end

          it { is_expected.to be_invalid }
        end

        context 'given a malformed space guid' do
          let(:params) do
            {
              name: 'rob',
              relationships: {
                organization: {
                  data: {
                    guid: 'socks'
                  },
                },
                spaces: {
                  data: [
                    { guid: 150000 }
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
