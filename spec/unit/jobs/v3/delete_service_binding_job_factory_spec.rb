require 'db_spec_helper'
require 'jobs/v3/delete_service_binding_job_factory'

module VCAP::CloudController
  module V3
    RSpec.describe DeleteServiceBindingFactory do
      let(:factory) { CreateServiceBindingFactory.new }

      describe '#for' do
        it 'should return route job actor when type is route' do
          actor = DeleteServiceBindingFactory.for(:route)
          expect(actor).to be_an_instance_of(DeleteServiceRouteBindingJobActor)
        end

        it 'should return credential job actor when type is credential' do
          actor = DeleteServiceBindingFactory.for(:credential)
          expect(actor).to be_an_instance_of(DeleteServiceCredentialBindingJobActor)
        end

        it 'raise for unknown types' do
          expect { DeleteServiceBindingFactory.for(:key) }.to raise_error(DeleteServiceBindingFactory::InvalidType)
        end
      end

      describe '#action' do
        it 'should return route action when type is route' do
          actor = DeleteServiceBindingFactory.action(:route, {})
          expect(actor).to be_an_instance_of(ServiceRouteBindingDelete)
        end

        it 'should return credential binding action when type is credential' do
          actor = DeleteServiceBindingFactory.action(:credential, {})
          expect(actor).to be_an_instance_of(V3::ServiceCredentialBindingDelete)
        end

        it 'raise for unknown types' do
          expect { DeleteServiceBindingFactory.action(:key, {}) }.to raise_error(DeleteServiceBindingFactory::InvalidType)
        end
      end
    end
  end
end
