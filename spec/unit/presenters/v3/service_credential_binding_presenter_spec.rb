require 'spec_helper'
require 'presenters/v3/service_credential_binding_presenter'

module VCAP
  module CloudController
    RSpec.describe Presenters::V3::ServiceCredentialBindingPresenter do
      let(:instance) { ManagedServiceInstance.make(guid: 'instance-guid') }
      let(:app) { AppModel.make(guid: 'app-guid', space: instance.space) }

      describe 'app bindings' do
        let(:credential_binding) do
          ServiceBinding.make(name: 'some-name', guid: 'some-guid', app: app, service_instance: instance).tap do |binding|
            binding.save_with_new_operation(
              {
                type: 'create',
                state: 'succeeded',
                description: 'some description'
              }
            )
          end
        end

        it 'should include the binding fields plus links and relationships' do
          presenter = described_class.new(credential_binding)
          expect(presenter.to_hash).to match(
            {
              guid: 'some-guid',
              type: 'app',
              name: 'some-name',
              created_at: credential_binding.created_at,
              updated_at: credential_binding.updated_at,
              last_operation: {
                type: 'create',
                state: 'succeeded',
                description: 'some description',
                updated_at: credential_binding.last_operation.updated_at,
                created_at: credential_binding.last_operation.created_at
              },
              relationships: {
                app: {
                  data: {
                    guid: 'app-guid'
                  }
                },
                service_instance: {
                  data: {
                    guid: 'instance-guid'
                  }
                }
              },
              links: {
                self: {
                  href: %r{.*/v3/service_credential_bindings/some-guid}
                },
                details: {
                  href: %r{.*/v3/service_credential_bindings/some-guid/details}
                },
                parameters: {
                  href: %r{.*/v3/service_credential_bindings/some-guid/parameters}
                },
                app: {
                  href: %r{.*/v3/apps/app-guid}
                },
                service_instance: {
                  href: %r{.*/v3/service_instances/instance-guid}
                }
              }
            }
          )
        end

        context 'when name is not set' do
          let(:instance) { ServiceInstance.make(name: 'smashed-avocado') }
          let(:credential_binding) { ServiceBinding.make(service_instance: instance) }

          it 'should return null as the binding name' do
            presenter = described_class.new(credential_binding)
            expect(presenter.to_hash[:name]).to be_nil
          end
        end
      end

      describe 'key bindings' do
        let(:credential_binding) do
          ServiceKey.make(name: 'some-name', guid: 'some-guid', service_instance: instance)
        end

        it 'should include the binding fields plus links and relationships' do
          presenter = described_class.new(credential_binding)
          expect(presenter.to_hash).to match(
            {
              guid: 'some-guid',
              type: 'key',
              name: 'some-name',
              created_at: credential_binding.created_at,
              updated_at: credential_binding.updated_at,
              last_operation: nil,
              relationships: {
                service_instance: {
                  data: {
                    guid: 'instance-guid'
                  }
                }
              },
              links: {
                self: {
                  href: %r{.*/v3/service_credential_bindings/some-guid}
                },
                details: {
                  href: %r{.*/v3/service_credential_bindings/some-guid/details}
                },
                parameters: {
                  href: %r{.*/v3/service_credential_bindings/some-guid/parameters}
                },
                service_instance: {
                  href: %r{.*/v3/service_instances/instance-guid}
                }
              }
            }
          )
        end
      end

      describe 'for user provided service instances' do
        let(:instance) { UserProvidedServiceInstance.make(guid: 'instance-guid') }
        let(:credential_binding) { ServiceKey.make(name: 'some-name', guid: 'some-guid', service_instance: instance) }

        it 'should not include links.parameters' do
          presenter = described_class.new(credential_binding)
          expect(presenter.to_hash[:links]).to_not have_key(:parameters)
        end
      end

      context 'when a decorator is provided' do
        let(:decorator) { double('FakeDecorator') }

        before do
          allow(decorator).to receive(:decorate).with({}, array_including(credential_binding)).and_return({
            included: { resource: { guid: 'app-guid' } }
          })
        end

        let(:credential_binding) do
          ServiceBinding.make(name: 'some-name', guid: 'some-guid', app: app, service_instance: instance)
        end

        let(:result) { described_class.new(credential_binding, decorators: [decorator]).to_hash.deep_symbolize_keys }

        it 'uses the decorator' do
          expect(result[:included]).to match({ resource: { guid: 'app-guid' } })
        end
      end
    end
  end
end
