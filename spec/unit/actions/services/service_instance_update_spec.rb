require 'spec_helper'
require 'actions/services/service_instance_update'
module VCAP::CloudController
  describe ServiceInstanceUpdate do
    let(:services_event_repo) { double(Repositories::Services::EventRepository).as_null_object }
    let(:service_instance) { ManagedServiceInstance.make }

    describe 'updating multiple attributes' do
      let(:service_broker) { ServiceBroker.make }
      let(:service) { Service.make(plan_updateable: true, service_broker: service_broker) }
      let(:old_service_plan) { ServicePlan.make(:v2, service: service) }
      let(:new_service_plan) { ServicePlan.make(:v2, service: service) }
      let(:service_instance) { ManagedServiceInstance.make(service_plan: old_service_plan) }

      before do
        stub_update service_instance
      end

      it 'can update all the attributes at the same time' do
        updated_name = 'New name'
        updated_parameters = { 'thing1' => 'thing2' }
        updated_tags = ['tag1', 'tag2']
        request_attrs = {
          'parameters' => updated_parameters,
          'name' => updated_name,
          'tags' => updated_tags,
          'service_plan_guid' => new_service_plan.guid
        }

        service_instance_update = ServiceInstanceUpdate.new(
          accepts_incomplete: false,
          services_event_repository: services_event_repo
        )
        service_instance_update.update_service_instance(service_instance, request_attrs)

        service_instance.reload

        expect(service_instance.name).to eq(updated_name)
        expect(service_instance.tags).to eq(updated_tags)
        expect(service_instance.service_plan.guid).to eq(new_service_plan.guid)

        expect(
          a_request(:patch, update_url(service_instance)).with(
            body: hash_including({
                'parameters' => updated_parameters,
                'plan_id' => new_service_plan.broker_provided_id
              })
          )
        ).to have_been_made.once
      end
    end
  end
end
