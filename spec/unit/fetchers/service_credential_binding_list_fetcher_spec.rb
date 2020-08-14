require 'spec_helper'
require 'fetchers/service_credential_binding_list_fetcher'

module VCAP
  module CloudController
    RSpec.describe ServiceCredentialBindingListFetcher do
      let(:message) { nil }
      let(:fetcher) { ServiceCredentialBindingListFetcher.new }

      describe 'no bindings' do
        it 'returns an empty result' do
          expect(fetcher.fetch(space_guids: :all, message: message).all).to eql([])
        end
      end

      describe 'app and key bindings' do
        let(:space) { VCAP::CloudController::Space.make }
        let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
        let!(:key_binding) { VCAP::CloudController::ServiceKey.make(service_instance: instance) }
        let!(:app_binding) { VCAP::CloudController::ServiceBinding.make(service_instance: instance, name: Sham.name) }

        context 'when getting everything' do
          it 'returns both key and app bindings' do
            bindings = fetcher.fetch(space_guids: :all, message: message).all
            binding_guids = bindings.map(&:guid)

            expect(binding_guids).to contain_exactly(key_binding.guid, app_binding.guid)
          end
        end

        context 'when limiting to a space' do
          let(:other_space) { VCAP::CloudController::Space.make }
          let(:other_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: other_space) }
          let!(:key_other_binding) { VCAP::CloudController::ServiceKey.make(service_instance: other_instance) }
          let!(:app_other_binding) { VCAP::CloudController::ServiceBinding.make(service_instance: other_instance) }

          it 'returns only the bindings within that space' do
            bindings = fetcher.fetch(space_guids: [space.guid], message: message).all
            binding_guids = bindings.map(&:guid)

            expect(binding_guids).to contain_exactly(key_binding.guid, app_binding.guid)
          end
        end

        describe 'filters' do
          let(:message) { double('Filters', requested?: false) }
          let(:another_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
          let!(:another_key) { VCAP::CloudController::ServiceKey.make(service_instance: another_instance) }
          let!(:another_binding) { VCAP::CloudController::ServiceBinding.make(service_instance: another_instance, name: Sham.name) }

          it 'can filter by service instance name' do
            allow(message).to receive(:requested?).with(:service_instance_names).and_return(true)
            allow(message).to receive(:service_instance_names).and_return([instance.name])

            bindings = fetcher.fetch(space_guids: :all, message: message).all
            expect(bindings.map(&:guid)).to contain_exactly(key_binding.guid, app_binding.guid)
          end

          it 'can filter by service instance guid' do
            allow(message).to receive(:requested?).with(:service_instance_guids).and_return(true)
            allow(message).to receive(:service_instance_guids).and_return([instance.guid])

            bindings = fetcher.fetch(space_guids: :all, message: message).all
            expect(bindings.map(&:guid)).to contain_exactly(key_binding.guid, app_binding.guid)
          end

          it 'can filter by app name' do
            allow(message).to receive(:requested?).with(:app_names).and_return(true)
            allow(message).to receive(:app_names).and_return([app_binding.app.name, 'some-other-name'])

            bindings = fetcher.fetch(space_guids: :all, message: message).all
            expect(bindings.map(&:guid)).to contain_exactly(app_binding.guid)
          end

          it 'can filter by app guid' do
            allow(message).to receive(:requested?).with(:app_guids).and_return(true)
            allow(message).to receive(:app_guids).and_return([app_binding.app.guid, 'some-other-guid'])

            bindings = fetcher.fetch(space_guids: :all, message: message).all
            expect(bindings.map(&:guid)).to contain_exactly(app_binding.guid)
          end

          it 'can filter by binding name' do
            allow(message).to receive(:requested?).with(:names).and_return(true)
            allow(message).to receive(:names).and_return([key_binding.name, app_binding.name])

            bindings = fetcher.fetch(space_guids: :all, message: message).all
            expect(bindings.map(&:guid)).to contain_exactly(key_binding.guid, app_binding.guid)
          end

          it 'can filter by type' do
            allow(message).to receive(:requested?).with(:type).and_return(true)
            allow(message).to receive(:type).and_return('app', 'key')

            bindings = fetcher.fetch(space_guids: :all, message: message).all
            expect(bindings.map(&:guid)).to contain_exactly(app_binding.guid, another_binding.guid)

            bindings = fetcher.fetch(space_guids: :all, message: message).all
            expect(bindings.map(&:guid)).to contain_exactly(key_binding.guid, another_key.guid)
          end

          it 'returns all if no filter is passed' do
            bindings = fetcher.fetch(space_guids: :all, message: message).all
            expect(bindings.count).to eq(4)
          end

          it 'returns empty if there is no match' do
            allow(message).to receive(:requested?).with(:service_instance_guids).and_return(true)
            allow(message).to receive(:service_instance_guids).and_return(['fake-guid'])
            allow(message).to receive(:service_instance_names).and_return(['fake-name'])

            bindings = fetcher.fetch(space_guids: :all, message: message).all
            expect(bindings).to be_empty
          end

          it 'filters properly when multiple filters are set' do
            allow(message).to receive(:requested?).with(:names).and_return(true)
            allow(message).to receive(:requested?).with(:service_instance_guids).and_return(true)
            allow(message).to receive(:names).and_return([key_binding.name, another_binding.name])
            allow(message).to receive(:service_instance_guids).and_return([another_instance.guid])

            bindings = fetcher.fetch(space_guids: :all, message: message).all
            expect(bindings.map(&:guid)).to contain_exactly(another_binding.guid)
          end
        end
      end

      describe 'fetching app bindings' do
        let!(:app_binding) { VCAP::CloudController::ServiceBinding.make }

        it 'allows the last operation to be accessed' do
          app_binding.save_with_new_operation(
            {
              type: 'create',
              state: 'succeeded',
              description: 'some description'
            }
          )

          credential_binding = fetcher.fetch(space_guids: :all, message: message).first
          last_operation = credential_binding.last_operation

          expect(last_operation).to be_present

          expect(last_operation.type).to eql 'create'
          expect(last_operation.state).to eql 'succeeded'
          expect(last_operation.description).to eql 'some description'
          expect(last_operation.created_at).to be_present
          expect(last_operation.updated_at).to be_present
        end
      end
    end
  end
end
