require 'spec_helper'
require 'actions/service_instance_update_managed'

module VCAP::CloudController
  RSpec.describe ServiceInstanceUpdateManaged do
    describe '#update' do
      subject(:action) { described_class.new(event_repository) }

      let(:event_repository) do
        dbl = double(Repositories::ServiceEventRepository::WithUserActor)
        allow(dbl).to receive(:record_service_instance_event)
        allow(dbl).to receive(:user_audit_info)
        dbl
      end
      let(:message) { ServiceInstanceUpdateManagedMessage.new(body) }
      let(:org) { Organization.make }
      let(:space) { Space.make(organization: org) }
      let(:service_offering) { Service.make(plan_updateable: true) }
      let(:original_maintenance_info) { { version: '2.1.0', description: 'original version' } }
      let(:service_plan) { ServicePlan.make(service: service_offering, maintenance_info: original_maintenance_info) }
      let(:original_name) { 'foo' }
      let!(:service_instance) do
        si = VCAP::CloudController::ManagedServiceInstance.make(
          service_plan: service_plan,
          name: original_name,
          tags: %w(accounting mongodb),
          space: space,
          maintenance_info: original_maintenance_info
        )
        si.label_ids = [
          VCAP::CloudController::ServiceInstanceLabelModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value'),
          VCAP::CloudController::ServiceInstanceLabelModel.make(key_prefix: 'pre.fix', key_name: 'tail', value: 'fluffy')
        ]
        si.annotation_ids = [
          VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'to_delete', value: 'value').id,
          VCAP::CloudController::ServiceInstanceAnnotationModel.make(key_prefix: 'pre.fix', key_name: 'fox', value: 'bushy').id
        ]
        si
      end

      context 'when the update does not require communication with the broker' do
      end

      context 'when the update requires communication with the broker' do
        let(:new_plan) { ServicePlan.make }
        let(:body) do
          {
            name: 'new-name',
            parameters: { foo: 'bar' },
            tags: %w(bar quz),
            relationships: {
              service_plan: {
                data: {
                  guid: new_plan.guid
                }
              }
            }
          }
        end
      end
    end
  end
end
