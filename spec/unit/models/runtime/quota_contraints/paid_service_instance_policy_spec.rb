require 'spec_helper'

describe PaidServiceInstancePolicy do
  let(:org) { VCAP::CloudController::Organization.make quota_definition: quota }
  let(:space) { VCAP::CloudController::Space.make organization: org }
  let(:basic_service_plan) { VCAP::CloudController::ServicePlan.make(free: true) }
  let(:paid_service_plan) { VCAP::CloudController::ServicePlan.make(free: false) }
  let(:service_instance) do
    VCAP::CloudController::ManagedServiceInstance.make_unsaved space: space, service_plan: @service_plan
  end
  let(:quota) { VCAP::CloudController::QuotaDefinition.make non_basic_services_allowed: non_basic_services_allowed }
  let(:error_name) { :random_error_name }

  let(:policy) { PaidServiceInstancePolicy.new(service_instance, quota, error_name) }

  context 'when quota is nil' do
    let(:quota) { nil }
    it 'does not add errors' do
      expect(policy).to validate_without_error(service_instance)
    end
  end

  context 'when non basic services are allowed' do
    let(:non_basic_services_allowed) { true }

    it 'allows creation of basic services' do
      @service_plan = basic_service_plan
      expect(policy).to validate_without_error(service_instance)
    end

    it 'allows creation of non basic services' do
      @service_plan = paid_service_plan
      expect(policy).to validate_without_error(service_instance)
    end
  end

  context 'when non basic services are not allowed' do
    let(:non_basic_services_allowed) { false }

    it 'allows creation of basic services' do
      @service_plan = basic_service_plan
      expect(policy).to validate_without_error(service_instance)
    end

    it 'does not allow creation of non basic services' do
      @service_plan = paid_service_plan
      expect(policy).to validate_with_error(service_instance, :service_plan, error_name)
    end
  end
end
