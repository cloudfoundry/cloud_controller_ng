require 'jobs/v3/create_service_binding_job_factory'

module VCAP::CloudController
  module V3
    RSpec.describe CreateServiceBindingFactory do
      let(:factory) { CreateServiceBindingFactory.new }

      describe '#for' do
        it 'should return route job actor when type is route' do
          actor = CreateServiceBindingFactory.for(:route)
          expect(actor).to be_an_instance_of(CreateRouteBindingJobActor)
        end

        it 'should return route job actor when type is credential' do
          actor = CreateServiceBindingFactory.for(:credential)
          expect(actor).to be_an_instance_of(CreateServiceCredentialBindingJobActor)
        end
      end
    end
  end
end
