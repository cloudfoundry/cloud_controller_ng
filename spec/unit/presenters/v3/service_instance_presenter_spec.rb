require 'spec_helper'
require 'presenters/v3/service_instance_presenter'

module VCAP::CloudController::Presenters::V3
  RSpec.describe ServiceInstancePresenter do
    let(:presenter) { described_class.new(service_instance) }
    let(:result) { presenter.to_hash.deep_symbolize_keys }

    before do
      VCAP::CloudController::ServiceInstanceLabelModel.make(
        key_name: 'release',
        value: 'stable',
        resource_guid: service_instance.guid
      )

      VCAP::CloudController::ServiceInstanceLabelModel.make(
        key_prefix: 'canberra.au',
        key_name: 'potato',
        value: 'mashed',
        resource_guid: service_instance.guid
      )

      VCAP::CloudController::ServiceInstanceAnnotationModel.make(
        key: 'altitude',
        value: '14,412',
        resource_guid: service_instance.guid,
      )

      VCAP::CloudController::ServiceInstanceAnnotationModel.make(
        key: 'maize',
        value: 'hfcs',
        resource_guid: service_instance.guid,
      )
    end

    context 'managed service instance' do
      let(:maintenance_info) { nil }
      let(:plan) { VCAP::CloudController::ServicePlan.make }
      let(:service_instance) do
        VCAP::CloudController::ManagedServiceInstance.make(
          service_plan: plan,
          name: 'denise-db',
          tags: ['tag1', 'tag2'],
          maintenance_info: maintenance_info,
          dashboard_url: 'https://my-fantistic-service.com',
        )
      end

      it 'presents the managed service instance' do
        expect(result).to eq({
          guid: service_instance.guid,
          name: 'denise-db',
          created_at: service_instance.created_at,
          updated_at: service_instance.updated_at,
          type: 'managed',
          tags: ['tag1', 'tag2'],
          maintenance_info: {},
          upgrade_available: false,
          dashboard_url: 'https://my-fantistic-service.com',
          last_operation: {},
          metadata: {
            labels: {
              release: 'stable',
              'canberra.au/potato': 'mashed'
            },
            annotations: {
              altitude: '14,412',
              maize: 'hfcs'
            }
          },
          relationships: {
            service_plan: {
              data: {
                guid: plan.guid,
                name: plan.name
              }
            },
            space: {
              data: {
                guid: service_instance.space.guid
              }
            }
          },
          links: {
            service_plan: {
              href: "#{link_prefix}/v3/service_plans/#{plan.guid}"
            },
            space: {
              href: "#{link_prefix}/v3/spaces/#{service_instance.space.guid}"
            },
            self: {
              href: "#{link_prefix}/v3/service_instances/#{service_instance.guid}"
            }
          }
        })
      end

      describe 'last_operation' do
        let(:last_operation) do
          VCAP::CloudController::ServiceInstanceOperation.make(
            description: 'did something cool'
          )
        end

        before do
          service_instance.service_instance_operation = last_operation
          service_instance.reload
          last_operation.reload
        end

        it 'presents the last operation' do
          expect(result[:last_operation]).to eq({
            type: 'create',
            state: 'succeeded',
            description: 'did something cool',
            created_at: last_operation.created_at,
            updated_at: last_operation.updated_at,
          })
        end
      end

      describe 'maintenance_info' do
        let(:maintenance_info) do
          {
            version: '1.0.0',
            description: 'huge improvement'
          }
        end

        it 'presents the maintenance info' do
          expect(result[:maintenance_info]).to eq(maintenance_info)
        end
      end

      describe 'upgrade available' do
        context 'plan has the same maintenance_info' do
          let(:maintenance_info) { { version: '1.0.0' } }
          let(:plan) { VCAP::CloudController::ServicePlan.make(maintenance_info: maintenance_info) }

          it 'is false' do
            expect(result[:upgrade_available]).to be(false)
          end
        end

        context 'plan has the different maintenance_info' do
          let(:maintenance_info) { { version: '1.0.0' } }
          let(:plan) { VCAP::CloudController::ServicePlan.make(maintenance_info: { version: '2.0.0' }) }

          it 'is true' do
            expect(result[:upgrade_available]).to be(true)
          end
        end
      end
    end

    context 'user-provided service instance' do
      let(:service_instance) do
        VCAP::CloudController::UserProvidedServiceInstance.make(
          name: 'yu-db',
          tags: ['tag3', 'tag4'],
          syslog_drain_url: 'https://syslog-drain.com',
          route_service_url: 'https://route-service.com',
        )
      end

      it 'presents the user-provided service instance' do
        expect(result).to eq({
          guid: service_instance.guid,
          name: 'yu-db',
          created_at: service_instance.created_at,
          updated_at: service_instance.updated_at,
          type: 'user-provided',
          tags: ['tag3', 'tag4'],
          syslog_drain_url: 'https://syslog-drain.com',
          route_service_url: 'https://route-service.com',
          metadata: {
            labels: {
              release: 'stable',
              'canberra.au/potato': 'mashed'
            },
            annotations: {
              altitude: '14,412',
              maize: 'hfcs'
            }
          },
          relationships: {
            space: {
              data: {
                guid: service_instance.space.guid
              }
            }
          },
          links: {
            space: {
              href: "#{link_prefix}/v3/spaces/#{service_instance.space.guid}"
            },
            self: {
              href: "#{link_prefix}/v3/service_instances/#{service_instance.guid}"
            }
          }
        })
      end
    end
  end
end
