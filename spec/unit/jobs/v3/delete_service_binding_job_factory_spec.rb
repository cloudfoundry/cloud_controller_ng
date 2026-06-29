require 'spec_helper'
require 'jobs/v3/delete_service_binding_job_factory'

module VCAP::CloudController
  module V3
    RSpec.describe DeleteServiceBindingFactory do
      let(:factory) { CreateServiceBindingFactory.new }

      describe '#for' do
        it 'returns route job actor when type is route' do
          actor = described_class.for(:route)
          expect(actor).to be_an_instance_of(DeleteServiceRouteBindingJobActor)
        end

        it 'returns credential job actor when type is credential' do
          actor = described_class.for(:credential)
          expect(actor).to be_an_instance_of(DeleteServiceCredentialBindingJobActor)
        end

        it 'returns credential job actor when type is key' do
          actor = described_class.for(:key)
          expect(actor).to be_an_instance_of(DeleteServiceKeyBindingJobActor)
        end

        it 'raise for unknown types' do
          expect { described_class.for(:unknown) }.to raise_error(described_class::InvalidType)
        end
      end

      describe '#action' do
        it 'returns route action when type is route' do
          actor = described_class.action(:route, {})
          expect(actor).to be_an_instance_of(ServiceRouteBindingDelete)
        end

        it 'returns credential binding action when type is credential' do
          actor = described_class.action(:credential, {})
          expect(actor).to be_an_instance_of(V3::ServiceCredentialBindingDelete)
        end

        it 'returns credential binding action when type is key' do
          actor = described_class.action(:key, {})
          expect(actor).to be_an_instance_of(V3::ServiceCredentialBindingDelete)
        end

        it 'raise for unknown types' do
          expect { described_class.action(:unknown, {}) }.to raise_error(described_class::InvalidType)
        end
      end

      describe '#type_of' do
        it 'returns the type constant for a binding model' do
          expect(described_class.type_of(create(:route_binding))).to eq(:route)
          expect(described_class.type_of(create(:service_key))).to eq(:key)
          expect(described_class.type_of(create(:service_binding))).to eq(:credential)
        end

        it 'raises on invalid input' do
          expect do
            described_class.type_of(create(:service_instance))
          end.to raise_error(described_class::InvalidType)
        end
      end
    end
  end
end
