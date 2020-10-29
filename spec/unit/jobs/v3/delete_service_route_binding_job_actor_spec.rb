require 'db_spec_helper'
require 'support/shared_examples/jobs/delayed_job'
require 'jobs/v3/delete_service_route_binding_job_actor'

module VCAP::CloudController
  module V3
    RSpec.describe DeleteServiceRouteBindingJobActor do
      let(:subject) do
        described_class.new
      end

      describe '#display_name' do
        it 'returns "service_route_bindings.delete"' do
          expect(subject.display_name).to eq('service_route_bindings.delete')
        end
      end

      describe '#resource_type' do
        it 'returns "service_route_binding"' do
          expect(subject.resource_type).to eq('service_route_binding')
        end
      end

      describe '#get_resource' do
        let(:binding) do
          RouteBinding.make
        end

        it 'returns the resource when it exists' do
          expect(subject.get_resource(binding.guid)).to eq(binding)
        end

        it 'returns nil when resource not found' do
          expect(subject.get_resource('fake_guid')).to be_nil
        end
      end
    end
  end
end
