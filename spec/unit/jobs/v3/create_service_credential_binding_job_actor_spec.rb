require 'db_spec_helper'
require 'support/shared_examples/jobs/delayed_job'
require 'jobs/v3/create_service_credential_binding_job_actor'

module VCAP::CloudController
  module V3
    RSpec.describe CreateServiceCredentialBindingJobActor do
      let(:subject) do
        described_class.new
      end

      describe '#display_name' do
        it 'returns "service_bindings.create"' do
          expect(subject.display_name).to eq('service_bindings.create')
        end
      end

      describe '#resource_type' do
        it 'returns "service_credential_binding"' do
          expect(subject.resource_type).to eq('service_credential_binding')
        end
      end

      describe '#get_resource' do
        let(:binding) do
          ServiceBinding.make
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
