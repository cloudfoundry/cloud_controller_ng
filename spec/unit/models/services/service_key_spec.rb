require 'spec_helper'

module VCAP::CloudController
  RSpec.describe VCAP::CloudController::ServiceKey, type: :model do
    let(:client) { double('broker client', unbind: nil, deprovision: nil) }

    before do
      allow_any_instance_of(Service).to receive(:client).and_return(client)
    end

    it { is_expected.to have_timestamp_columns }

    describe 'Associations' do
      it { is_expected.to have_associated :service_instance, associated_instance: ->(service_key) { ServiceInstance.make(space: service_key.space) } }
    end

    describe 'Validations' do
      it { is_expected.to validate_presence :service_instance }
      it { is_expected.to validate_presence :name }
      it { is_expected.to validate_db_presence :service_instance_id }
      it { is_expected.to validate_db_presence :credentials }
      it { is_expected.to validate_uniqueness [:name, :service_instance_id] }

      context 'MaxServiceKeysPolicy' do
        let(:service_key) { ServiceKey.make }
        let(:policy) { double(MaxServiceKeysPolicy) }
        let(:space_policy) { double(MaxServiceKeysPolicy) }

        it 'validates org quotas using MaxServiceKeysPolicy' do
          expect(MaxServiceKeysPolicy).to receive(:new).
            with(service_key, 1, service_key.service_instance.organization.quota_definition, :service_keys_quota_exceeded).
            and_return(policy)
          expect(policy).to receive(:validate)
          expect(MaxServiceKeysPolicy).to receive(:new).with(service_key, 1, nil, :service_keys_space_quota_exceeded).and_return(space_policy)
          expect(space_policy).to receive(:validate)

          service_key.valid?
        end

        context 'with a space quota' do
          let(:space_quota) { SpaceQuotaDefinition.make(organization: service_key.service_instance.organization) }

          before do
            quota = space_quota
            service_key.service_instance.space.space_quota_definition = quota
          end

          it 'validates space quotas using MaxServiceKeysPolicy' do
            expect(MaxServiceKeysPolicy).to receive(:new).
              with(service_key, 1, service_key.service_instance.organization.quota_definition, :service_keys_quota_exceeded).
              and_return(policy)
            expect(policy).to receive(:validate)
            expect(MaxServiceKeysPolicy).to receive(:new).with(service_key, 1, space_quota, :service_keys_space_quota_exceeded).and_return(space_policy)
            expect(space_policy).to receive(:validate)

            service_key.valid?
          end
        end
      end
    end

    describe 'Serialization' do
      it { is_expected.to export_attributes :name, :service_instance_guid, :credentials }
      it { is_expected.to import_attributes :name, :service_instance_guid, :credentials }
    end

    describe '#new' do
      it 'has a guid when constructed' do
        service_key = VCAP::CloudController::ServiceKey.new
        expect(service_key.guid).to be
      end
    end

    it_behaves_like 'a model with an encrypted attribute' do
      let(:service_instance) { ManagedServiceInstance.make }

      def new_model
        ServiceKey.make(
          name: Sham.name,
          service_instance: service_instance,
          credentials: value_to_encrypt
        )
      end

      let(:encrypted_attr) { :credentials }
      let(:attr_salt) { :salt }
    end

    describe '#credhub_reference?' do
      context 'when it is not a credhub reference' do
        let(:service_key) { ServiceKey.make }

        it 'returns true' do
          expect(service_key.credhub_reference?).to eq(false)
        end
      end

      context 'when it is a credhub reference' do
        let(:credhub_ref) do
          {
            'credhub-ref' => '((/c/my-service-broker/my-service/faa677f5-25cd-4f1e-8921-14a9d5ab48b8/credentials))'
          }
        end
        let(:service_key) { ServiceKey.make(credentials: credhub_ref) }

        it 'returns false' do
          expect(service_key.credhub_reference?).to eq(true)
        end
      end
    end

    describe '#credhub_reference' do
      context 'when the service key has no credentials' do
        let(:service_key) { ServiceKey.make(credentials: nil) }

        it 'returns nil' do
          expect(service_key.credhub_reference).to be_nil
        end
      end

      context 'when it does not have a credhub reference' do
        let(:service_key) { ServiceKey.make }

        it 'returns nil' do
          expect(service_key.credhub_reference).to be_nil
        end
      end

      context 'when it has a credhub reference' do
        let(:credential_name) { '((/c/my-service-broker/my-service/faa677f5-25cd-4f1e-8921-14a9d5ab48b8/credentials))' }
        let(:credhub_ref) { { 'credhub-ref' => credential_name } }
        let(:service_key) { ServiceKey.make(credentials: credhub_ref) }

        it 'returns false' do
          expect(service_key.credhub_reference).to eq(credential_name)
        end
      end
    end

    describe 'user_visibility_filter' do
      let!(:service_instance) { ManagedServiceInstance.make }
      let!(:service_key) { ServiceKey.make(service_instance: service_instance) }
      let!(:other_key) { ServiceKey.make }
      let(:developer) { make_developer_for_space(service_instance.space) }
      let(:auditor) { make_auditor_for_space(service_instance.space) }
      let(:other_user) { User.make }

      it 'only open to the space developers' do
        visible_to_developer = ServiceKey.user_visible(developer)
        visible_to_auditor = ServiceKey.user_visible(auditor)
        visible_to_other_user = ServiceKey.user_visible(other_user)

        expect(visible_to_developer.all).to eq [service_key]
        expect(visible_to_auditor.all).to be_empty
        expect(visible_to_other_user.all).to be_empty
      end
    end

    describe '#save_with_attributes_and_new_operation' do
      let(:service_instance) { ServiceInstance.make }
      let(:binding) {
        ServiceKey.new(
          service_instance: service_instance,
          credentials:      {},
          name:             'foo',
        )
      }

      it 'creates a new last_operation object and associates it with the binding' do
        last_operation = {
          state: 'in progress',
          type: 'create',
          description: '10%'
        }
        binding.save_with_attributes_and_new_operation({}, last_operation)

        expect(binding.last_operation.state).to eq 'in progress'
        expect(binding.last_operation.description).to eq '10%'
        expect(binding.last_operation.type).to eq 'create'
        expect(ServiceKey.where(guid: binding.guid).count).to eq(1)
      end

      context 'when saving the binding operation fails' do
        before do
          allow(ServiceKeyOperation).to receive(:create).and_raise(Sequel::DatabaseError, 'failed to create new-binding operation')
        end

        it 'should rollback the binding' do
          expect { binding.save_with_attributes_and_new_operation({}, { state: 'will fail' }) }.to raise_error(Sequel::DatabaseError)
          expect(ServiceKey.where(guid: binding.guid).count).to eq(0)
        end
      end

      context 'when called twice' do
        it 'does save the second operation' do
          binding.save_with_attributes_and_new_operation({}, { state: 'in progress', type: 'create', description: 'description' })
          binding.save_with_attributes_and_new_operation({}, { state: 'in progress', type: 'delete' })

          expect(binding.last_operation.state).to eq 'in progress'
          expect(binding.last_operation.type).to eq 'delete'
          expect(binding.last_operation.description).to eq nil
          expect(ServiceKey.where(guid: binding.guid).count).to eq(1)
          expect(ServiceKeyOperation.where(service_key_id: binding.id).count).to eq(1)
        end
      end

      context 'when attributes are passed in' do
        let(:credentials) { { password: 'rice' } }
        let(:attributes) {
          {
            name: 'gohan',
            credentials: credentials,
          }
        }
        let(:last_operation) { {
          state: 'in progress',
          type: 'create',
          description: '10%'
        }
        }

        it 'updates the attributes' do
          binding.save_with_attributes_and_new_operation(attributes, last_operation)
          binding.reload
          expect(binding.last_operation.state).to eq 'in progress'
          expect(binding.last_operation.description).to eq '10%'
          expect(binding.last_operation.type).to eq 'create'
          expect(binding.name).to eq 'gohan'
          expect(binding.credentials).to eq(credentials.with_indifferent_access)
          expect(ServiceKey.where(guid: binding.guid).count).to eq(1)
        end

        it 'only saves permitted attributes' do
          expect {
            binding.save_with_attributes_and_new_operation(attributes.merge(
                                                             parameters: {
                                                               foo: 'bar',
                                                               ding: 'dong'
                                                             },
                                                             endpoints: [{ host: 'mysqlhost', ports: ['3306'] }],
            ),
              last_operation
            )
          }.not_to raise_error
        end
      end
    end

    describe '#terminal_state?' do
      let(:service_binding) { ServiceKey.make }
      let(:operation) { ServiceKeyOperation.make(state: state) }

      before do
        service_binding.service_key_operation = operation
      end

      context 'when state is succeeded' do
        let(:state) { 'succeeded' }

        it 'returns true' do
          expect(service_binding.terminal_state?).to be true
        end
      end

      context 'when state is failed' do
        let(:state) { 'failed' }

        it 'returns true when state is `failed`' do
          expect(service_binding.terminal_state?).to be true
        end
      end

      context 'when state is something else' do
        let(:state) { 'in progress' }

        it 'returns false' do
          expect(service_binding.terminal_state?).to be false
        end
      end

      context 'when binding operation is missing' do
        let(:operation) { nil }

        it 'returns true' do
          expect(service_binding.terminal_state?).to be true
        end
      end
    end

    describe 'operation_in_progress?' do
      let(:service_instance) { ManagedServiceInstance.make }
      let(:service_key) { ServiceKey.make(service_instance: service_instance) }

      context 'when the service key has been created synchronously' do
        it 'returns false' do
          expect(service_key.operation_in_progress?).to be false
        end
      end

      context 'when the service key is being created asynchronously' do
        let(:state) {}
        let(:operation) { ServiceKeyOperation.make(state: state) }

        before do
          service_key.service_key_operation = operation
        end

        context 'and the operation is in progress' do
          let(:state) { 'in progress' }

          it 'returns true' do
            expect(service_key.operation_in_progress?).to be true
          end
        end

        context 'and the operation has failed' do
          let(:state) { 'failed' }

          it 'returns false' do
            expect(service_key.operation_in_progress?).to be false
          end
        end

        context 'and the operation has succeeded' do
          let(:state) { 'succeeded' }

          it 'returns false' do
            expect(service_key.operation_in_progress?).to be false
          end
        end
      end
    end

    describe '#destroy' do
      it 'cascades deletion of related dependencies' do
        binding = ServiceKey.make
        ServiceKeyLabelModel.make(key_name: 'foo', value: 'bar', service_key: binding)
        ServiceKeyAnnotationModel.make(key_name: 'baz', value: 'wow', service_key: binding)
        last_operation = ServiceKeyOperation.make
        binding.service_key_operation = last_operation

        binding.destroy

        expect(ServiceKey.find(guid: binding.guid)).to be_nil
        expect(ServiceKeyOperation.find(id: last_operation.id)).to be_nil
        expect(ServiceKeyLabelModel.find(resource_guid: binding.guid)).to be_nil
        expect(ServiceKeyAnnotationModel.find(resource_guid: binding.guid)).to be_nil
      end
    end
  end
end
