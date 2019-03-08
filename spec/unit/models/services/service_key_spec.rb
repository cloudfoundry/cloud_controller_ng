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
      let(:other_user) { FactoryBot.create(:user) }

      it 'only open to the space developers' do
        visible_to_developer = ServiceKey.user_visible(developer)
        visible_to_auditor = ServiceKey.user_visible(auditor)
        visible_to_other_user = ServiceKey.user_visible(other_user)

        expect(visible_to_developer.all).to eq [service_key]
        expect(visible_to_auditor.all).to be_empty
        expect(visible_to_other_user.all).to be_empty
      end
    end
  end
end
