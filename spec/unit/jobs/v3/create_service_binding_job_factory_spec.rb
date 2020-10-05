require 'db_spec_helper'
require 'jobs/v3/create_service_binding_job_factory'

module VCAP::CloudController
  module V3
    RSpec.describe CreateServiceBindingFactory do
      let(:factory) { CreateServiceBindingFactory.new }

      describe '#for' do
        it 'should return route job actor when type is route' do
          actor = CreateServiceBindingFactory.for(:route)
          expect(actor).to be_an_instance_of(CreateServiceRouteBindingJobActor)
        end

        it 'should return credential job actor when type is credential' do
          actor = CreateServiceBindingFactory.for(:credential)
          expect(actor).to be_an_instance_of(CreateServiceCredentialBindingJobActor)
        end

        it 'raise for unknown types' do
          expect { CreateServiceBindingFactory.for(:key) }.to raise_error(CreateServiceBindingFactory::InvalidType)
        end
      end

      describe '#action' do
        it 'should return route action when type is route' do
          actor = CreateServiceBindingFactory.action(:route, {}, {})
          expect(actor).to be_an_instance_of(ServiceRouteBindingCreate)
        end

        it 'should return credential binding action when type is credential' do
          actor = CreateServiceBindingFactory.action(:credential, {}, {})
          expect(actor).to be_an_instance_of(ServiceCredentialBindingCreate)
        end

        it 'raise for unknown types' do
          expect { CreateServiceBindingFactory.action(:key, {}, {}) }.to raise_error(CreateServiceBindingFactory::InvalidType)
        end
      end

    end
  end
end
