require 'spec_helper'

RSpec.describe PaidServiceInstancePolicy do
  let(:org) { create(:organization, quota_definition: quota) }
  let(:space) { create(:space, organization: org) }
  let(:basic_service_plan) { create(:service_plan, free: true) }
  let(:paid_service_plan) { create(:service_plan, free: false) }
  let(:service_instance) do
    build(:managed_service_instance, space: space, service_plan: @service_plan)
  end
  let(:quota) { create(:quota_definition, non_basic_services_allowed:) }
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
