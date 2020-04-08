require 'spec_helper'
require 'actions/space_quotas_create'
require 'messages/space_quotas_create_message'

module VCAP::CloudController
  RSpec.describe SpaceQuotasCreate do
    describe 'create' do
      subject(:space_quotas_create) { SpaceQuotasCreate.new }

      let(:org) { VCAP::CloudController::Organization.make(guid: 'some-org') }
      let(:space) { VCAP::CloudController::Space.make(guid: 'some-space', organization: org) }
      let(:message) do
        VCAP::CloudController::SpaceQuotasCreateMessage.new({
          name: 'my-name',
          relationships: {
            organization: {
              data: {
                guid: org.guid
              }
            }
          }
        })
      end

      let(:message_with_params) do
        VCAP::CloudController::SpaceQuotasCreateMessage.new({
          name: 'my-name',
          apps: {
            total_memory_in_mb: 5,
            per_process_memory_in_mb: 6,
            total_instances: 7,
            per_app_tasks: 8,
          },
          services: {
            paid_services_allowed: false,
            total_service_instances: 9,
            total_service_keys: 10,
          },
          routes: {
            total_routes: 47,
            total_reserved_ports: 5,
          },
          relationships: {
            organization: {
              data: {
                guid: org.guid
              }
            },
            spaces: {
              data: [
                { guid: space.guid }
              ]
            }
          }
        })
      end

      context 'when creating a space quota' do
        context 'using only the required params' do
          it 'creates a organization quota with the correct values' do
            space_quota = space_quotas_create.create(message, organization: org)

            expect(space_quota.name).to eq('my-name')

            expect(space_quota.organization).to eq(org)

            expect(space_quota.memory_limit).to eq(-1)
            expect(space_quota.instance_memory_limit).to eq(-1)
            expect(space_quota.app_instance_limit).to eq(-1)
            expect(space_quota.app_task_limit).to eq(-1)

            expect(space_quota.total_services).to eq(-1)
            expect(space_quota.total_service_keys).to eq(-1)
            expect(space_quota.non_basic_services_allowed).to eq(true)

            expect(space_quota.total_routes).to eq(-1)
            expect(space_quota.total_reserved_route_ports).to eq(-1)

            expect(space_quota.spaces.count).to eq(0)
          end
        end

        context 'using provided params' do
          it 'creates a organization quota with the correct values' do
            space_quota = space_quotas_create.create(message_with_params, organization: org)

            expect(space_quota.name).to eq('my-name')

            expect(space_quota.memory_limit).to eq(5)
            expect(space_quota.instance_memory_limit).to eq(6)
            expect(space_quota.app_instance_limit).to eq(7)
            expect(space_quota.app_task_limit).to eq(8)

            expect(space_quota.total_services).to eq(9)
            expect(space_quota.total_service_keys).to eq(10)
            expect(space_quota.non_basic_services_allowed).to eq(false)

            expect(space_quota.total_routes).to eq(47)
            expect(space_quota.total_reserved_route_ports).to eq(5)

            expect(space_quota.organization).to eq(org)

            expect(space_quota.spaces.count).to eq(1)
          end
        end
      end

      context 'when one or more of the space guids are invalid' do
        context 'because the space does not exist' do
          let(:invalid_space_guid) { 'invalid_space_guid' }
          let(:message_with_invalid_space_guid) do
            VCAP::CloudController::SpaceQuotasCreateMessage.new({
              'name' => 'my-name',
              'relationships' => {
                organization: { data: [{ guid: org.guid }] },
                spaces: { data: [{ guid: space.guid }, { guid: invalid_space_guid }] }
              }
            })
          end

          it 'raises a human-friendly error' do
            expect {
              space_quotas_create.create(message_with_invalid_space_guid, organization: org)
            }.to raise_error(SpaceQuotasCreate::Error, "Spaces with guids [\"#{invalid_space_guid}\"] do not exist " \
                'within the organization specified, or you do not have access to them.')
          end
        end

        context 'because the space exists in a different org' do
          let(:invalid_space) { Space.make(guid: 'invalid-space-guid', organization: Organization.make) }

          let(:message_with_invalid_space_guid) do
            VCAP::CloudController::SpaceQuotasCreateMessage.new({
              'name' => 'my-name',
              'relationships' => {
                organization: { data: [{ guid: org.guid }] },
                spaces: { data: [{ guid: space.guid }, { guid: invalid_space.guid }] }
              }
            })
          end

          it 'raises a human-friendly error' do
            expect {
              space_quotas_create.create(message_with_invalid_space_guid, organization: org)
            }.to raise_error(SpaceQuotasCreate::Error, "Spaces with guids [\"#{invalid_space.guid}\"] do not exist " \
                'within the organization specified, or you do not have access to them.')
          end
        end
      end

      context 'when a model validation fails' do
        it 'raises an error' do
          errors = Sequel::Model::Errors.new
          errors.add(:blork, 'is busted')
          expect(VCAP::CloudController::SpaceQuotaDefinition).to receive(:create).
            and_raise(Sequel::ValidationFailed.new(errors))

          expect {
            space_quotas_create.create(message, organization: org)
          }.to raise_error(SpaceQuotasCreate::Error, 'blork is busted')
        end

        context 'when it is a uniqueness error' do
          before do
            space_quotas_create.create(message, organization: org)
          end

          it 'raises a human-friendly error' do
            expect {
              space_quotas_create.create(message, organization: org)
            }.to raise_error(SpaceQuotasCreate::Error, "Space Quota '#{message.name}' already exists.")
          end
        end
      end
    end
  end
end
