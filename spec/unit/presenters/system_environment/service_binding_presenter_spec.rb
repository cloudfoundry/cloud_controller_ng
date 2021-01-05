require 'spec_helper'
require 'presenters/system_environment/service_binding_presenter'

module VCAP::CloudController
  RSpec.describe ServiceBindingPresenter do
    context 'for a managed service instance' do
      let(:service) { Service.make(requires: ['syslog_drain'], label: Sham.label) }
      let(:service_plan) { ServicePlan.make(name: Sham.name, service: service) }
      let(:service_instance) do
        ManagedServiceInstance.make(
          name:         instance_name,
          service_plan: service_plan,
        )
      end
      let(:instance_name) { Sham.name }
      let(:binding_options) { nil }
      let(:service_binding) do
        ServiceBinding.make(
          name:             binding_name,
          service_instance: service_instance,
        )
      end
      let(:binding_name) { nil }

      context 'with syslog_drain_url' do
        before do
          service_binding.update(syslog_drain_url: 'syslog://example.com:514')
        end

        describe '#to_hash' do
          subject { ServiceBindingPresenter.new(service_binding, include_instance: true).to_hash }

          specify do
            expect(subject.fetch(:syslog_drain_url)).to eq('syslog://example.com:514')
          end
        end
      end

      describe '#to_hash' do
        let(:result) { ServiceBindingPresenter.new(service_binding, include_instance: true).to_hash }

        it 'presents the service binding as a hash' do
          expect(result).to be_instance_of(Hash)

          expect(result).to have_key(:label)
          expect(result).to have_key(:name)
          expect(result).to have_key(:binding_guid)
          expect(result).to have_key(:credentials)
          expect(result).to have_key(:plan)
          expect(result).to have_key(:provider)
          expect(result).to have_key(:tags)
          expect(result).to have_key(:instance_name)
          expect(result).to have_key(:instance_guid)
          expect(result).to have_key(:binding_name)
        end

        specify do
          expect(result.fetch(:credentials)).to eq(service_binding.credentials)
        end

        it 'sets the binding id' do
          expect(result[:binding_guid]).to eq(service_binding.guid)
        end

        it 'sets the instance_name' do
          expect(result[:instance_name]).to eq(instance_name)
        end

        it 'sets the instance_id' do
          expect(result[:instance_guid]).to eq(service_instance.guid)
        end

        context 'when the binding has a name' do
          let(:binding_name) { 'bob' }

          it 'sets the "name" key to the binding name' do
            expect(result[:name]).to eq(binding_name)
          end

          it 'includes the binding_name' do
            expect(result[:binding_name]).to eq(binding_name)
          end
        end

        context 'when the binding has no name' do
          let(:binding_name) { nil }

          it 'sets the "name" key to the instance name' do
            expect(result[:name]).to eq(instance_name)
          end

          it 'sets the "binding_name" to null' do
            expect(result[:binding_name]).to eq(nil)
          end
        end
      end
    end

    context 'for a provided service instance' do
      let(:service_instance) do
        UserProvidedServiceInstance.make
      end

      let(:service_binding) do
        ServiceBinding.make(service_instance: service_instance)
      end

      describe '#to_hash' do
        subject { ServiceBindingPresenter.new(service_binding, include_instance: true).to_hash }

        it { is_expected.to be_instance_of(Hash) }
        it { is_expected.to have_key(:label) }
        it { is_expected.to have_key(:credentials) }
        it { is_expected.to have_key(:tags) }
      end
    end
  end
end
