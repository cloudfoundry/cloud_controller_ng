require 'spec_helper'
require 'fetchers/service_credential_binding_list_fetcher'
require 'messages/service_credential_bindings_list_message'

module VCAP
  module CloudController
    RSpec.describe ServiceCredentialBindingListFetcher do
      let(:params) { {} }
      let(:message) { ServiceCredentialBindingsListMessage.from_params(params) }
      let(:fetcher) { ServiceCredentialBindingListFetcher.new }

      describe 'no bindings' do
        it 'returns an empty result' do
          expect(fetcher.fetch(space_guids: :all, message: message).all).to eql([])
        end
      end

      describe 'app and key bindings' do
        let(:space) { VCAP::CloudController::Space.make }
        let(:instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }

        let(:key_details) {
          {
            credentials: '{"some":"key"}'
          }
        }

        let(:app_binding_details) {
          {
            credentials: '{"some":"app secret"}',
            syslog_drain_url: 'http://example.com/drain-app',
            volume_mounts: ['ccc', 'ddd']
          }
        }
        let!(:key_binding) { VCAP::CloudController::ServiceKey.make(service_instance: instance, **key_details) }
        let!(:app_binding) { VCAP::CloudController::ServiceBinding.make(service_instance: instance, name: Sham.name, **app_binding_details) }

        context 'when getting everything' do
          it 'returns both key and app bindings' do
            bindings = fetcher.fetch(space_guids: :all, message: message).all
            to_hash = ->(b) {
              {
                guid: b.guid,
                credentials: b.credentials,
                syslog_drain_url: b.try(:syslog_drain_url) || nil,
                volume_mounts: b.try(:volume_mount) || []
              }
            }

            actual_bindings = bindings.map { |b| to_hash.call(b) }
            expect(actual_bindings).to contain_exactly(to_hash.call(key_binding), to_hash.call(app_binding))
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
          let(:another_instance) { VCAP::CloudController::ManagedServiceInstance.make(space: space) }
          let!(:another_key) { VCAP::CloudController::ServiceKey.make(service_instance: another_instance) }
          let!(:another_binding) { VCAP::CloudController::ServiceBinding.make(service_instance: another_instance, name: Sham.name) }

          context 'service instance name' do
            let(:params) { { 'service_instance_names' => instance.name } }
            it 'returns the right result' do
              bindings = fetcher.fetch(space_guids: :all, message: message).all
              expect(bindings.map(&:guid)).to contain_exactly(key_binding.guid, app_binding.guid)
            end
          end

          context 'service instance guid' do
            let(:params) { { 'service_instance_guids' => instance.guid } }
            it 'returns the right result' do
              bindings = fetcher.fetch(space_guids: :all, message: message).all
              expect(bindings.map(&:guid)).to contain_exactly(key_binding.guid, app_binding.guid)
            end
          end

          context 'app name' do
            let(:params) { { 'app_names' => "#{app_binding.app.name},'some-other-name'" } }
            it 'can filter by app name' do
              bindings = fetcher.fetch(space_guids: :all, message: message).all
              expect(bindings.map(&:guid)).to contain_exactly(app_binding.guid)
            end
          end

          context 'app guid' do
            let(:params) { { 'app_guids' => "#{app_binding.app.guid}, 'some-other-guid'" } }
            it 'returns the right result' do
              bindings = fetcher.fetch(space_guids: :all, message: message).all
              expect(bindings.map(&:guid)).to contain_exactly(app_binding.guid)
            end
          end

          context 'binding name' do
            let(:params) { { 'names' => "#{key_binding.name},#{app_binding.name}" } }
            it 'returns the right result' do
              bindings = fetcher.fetch(space_guids: :all, message: message).all
              expect(bindings.map(&:guid)).to contain_exactly(key_binding.guid, app_binding.guid)
            end
          end

          context 'type' do
            context 'app' do
              let(:params) { { 'type' => 'app' } }

              it 'returns the right result' do
                bindings = fetcher.fetch(space_guids: :all, message: message).all
                expect(bindings.map(&:guid)).to contain_exactly(app_binding.guid, another_binding.guid)
              end
            end

            context 'key' do
              let(:params) { { type: 'key' } }

              it 'returns the right result' do
                bindings = fetcher.fetch(space_guids: :all, message: message).all
                expect(bindings.map(&:guid)).to contain_exactly(key_binding.guid, another_key.guid)
              end
            end
          end

          it 'returns all if no filter is passed' do
            bindings = fetcher.fetch(space_guids: :all, message: message).all
            expect(bindings.count).to eq(4)
          end

          context 'when there is no match' do
            let(:params) {
              { service_instance_guids: ['fake-guid'], service_instance_names: ['fake-name'] }
            }
            it 'returns empty' do
              bindings = fetcher.fetch(space_guids: :all, message: message).all
              expect(bindings).to be_empty
            end
          end

          context 'when multiple filters are passed' do
            let(:params) {
              { names: [key_binding.name, another_binding.name], service_instance_guids: [another_instance.guid] }
            }
            it 'returns the right result' do
              bindings = fetcher.fetch(space_guids: :all, message: message).all
              expect(bindings.map(&:guid)).to contain_exactly(another_binding.guid)
            end
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
