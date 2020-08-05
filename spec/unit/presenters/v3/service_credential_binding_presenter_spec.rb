require 'spec_helper'
require 'presenters/v3/service_credential_binding_presenter'

module VCAP
  module CloudController
    RSpec.describe Presenters::V3::ServiceCredentialBindingPresenter do
      CredentialBinding = Struct.new(:guid, :type, :created_at, :updated_at, :name,
        :last_operation_id, :last_operation_type, :last_operation_state,
        :last_operation_description, :last_operation_created_at, :last_operation_updated_at,
        :app_guid, :service_instance_guid
      )

      let(:service_instance) { 'instance-guid' }
      let(:app) { 'app-guid' }
      let(:last_operation) {
        ['1', 'create', 'succeeded', 'some description', 'last-operation-create-date', 'last-operation-update-date']
      }
      let(:credential_binding) {
        CredentialBinding.new('some-guid', 'some-type', 'create-date', 'update-date', 'some-name', *last_operation, app, service_instance)
      }

      it 'should include the binding fields plus links and relationships' do
        presenter = described_class.new(credential_binding)
        expect(presenter.to_hash).to match({
          guid: 'some-guid',
          type: 'some-type',
          name: 'some-name',
          created_at: 'create-date',
          updated_at: 'update-date',
          last_operation: {
            type: 'create',
            state: 'succeeded',
            description: 'some description',
            updated_at: 'last-operation-update-date',
            created_at: 'last-operation-create-date'
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
            app: {
              href: %r{.*/v3/apps/app-guid}
            },
            service_instance: {
              href: %r{.*/v3/service_instances/instance-guid}
            }
          }
        })
      end

      describe 'app not present' do
        let(:app) { nil }

        it 'should not include the app link' do
          result = described_class.new(credential_binding).to_hash
          expect(result[:links]).not_to have_key(:app)
        end

        it 'should not include the app relationship' do
          result = described_class.new(credential_binding).to_hash
          expect(result[:relationships]).not_to have_key(:app)
        end
      end

      describe 'last operation not present' do
        let(:last_operation) { [nil, nil, nil, nil, nil, nil] }

        it 'should include last_operation as null' do
          result = described_class.new(credential_binding).to_hash
          expect(result[:last_operation]).to eql(nil)
        end
      end
    end
  end
end
