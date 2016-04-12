require 'spec_helper'

describe MaxServiceKeysPolicy do
  let(:org) { VCAP::CloudController::Organization.make quota_definition: quota }
  let(:space) { VCAP::CloudController::Space.make organization: org }
  let(:service_instance) do
    service_plan = VCAP::CloudController::ServicePlan.make
    VCAP::CloudController::ManagedServiceInstance.make space: space, service_plan: service_plan
  end
  let(:service_key) { VCAP::CloudController::ServiceKey.make_unsaved service_instance: service_instance }
  let(:total_service_keys) { 2 }
  let(:quota) { VCAP::CloudController::QuotaDefinition.make total_service_keys: total_service_keys }
  let(:existing_service_key_count) { 0 }
  let(:error_name) { :random_error_name }

  let(:policy) { MaxServiceKeysPolicy.new(service_key, existing_service_key_count, quota, error_name) }

  def make_service_key
    VCAP::CloudController::ServiceKey.make service_instance: service_instance
  end

  context 'when quota is nil' do
    let(:quota) { nil }
    it 'does not add errors' do
      expect(policy).to validate_without_error(service_key)
    end
  end

  context 'when the quota is not reached' do
    it 'does not add errors' do
      expect(policy).to validate_without_error(service_key)
    end
  end

  context 'when the quota is unlimited' do
    let(:total_service_keys) { -1 }

    it 'does not add errors' do
      make_service_key
      expect(policy).to validate_without_error(service_key)
    end
  end

  context 'when the quota is reached' do
    let(:existing_service_key_count) { total_service_keys }
    before { total_service_keys.times { make_service_key } }

    context 'and the request is for a new service key' do
      it 'adds a service_key_quota_exceeded error on the quota' do
        expect(policy).to validate_with_error(service_key, :quota, error_name)
      end
    end

    context 'and the request is to update an existing service key' do
      let(:service_key) do
        VCAP::CloudController::ServiceKey.first
      end

      it 'allows updating the service' do
        expect(policy).to validate_without_error(service_key)
      end

      context 'and the quota is actually exceeded' do
        let(:existing_service_key_count) { total_service_keys + 1 }

        it 'adds an error on the quota if the quota is actually exceeded' do
          expect(policy).to validate_with_error(service_key, :quota, error_name)
        end
      end
    end
  end
end
