require "spec_helper"

describe MaxServiceInstancePolicy do
  let(:org) { VCAP::CloudController::Organization.make quota_definition: quota }
  let(:space) { VCAP::CloudController::Space.make organization: org }
  let(:service_instance) do
    service_plan = VCAP::CloudController::ServicePlan.make
    VCAP::CloudController::ManagedServiceInstance.make_unsaved space: space, service_plan: service_plan
  end
  let(:total_services) { 2 }
  let(:quota) { VCAP::CloudController::QuotaDefinition.make total_services: total_services }
  let(:existing_service_count) { 0 }
  let(:error_name) { :random_error_name }

  let(:policy) { MaxServiceInstancePolicy.new(service_instance, existing_service_count, quota, error_name) }

  def make_service_instance
    VCAP::CloudController::ManagedServiceInstance.make space: space
  end

  it 'counts only managed service instances' do
    total_services.times do
      VCAP::CloudController::UserProvidedServiceInstance.make space: space
    end

    expect(policy).to validate_without_error(service_instance)
  end

  context "when quota is nil" do
    let(:quota) { nil }
    it "does not add errors" do
      expect(policy).to validate_without_error(service_instance)
    end
  end

  context "when the quota is not reached" do
    it "does not add errors" do
      expect(policy).to validate_without_error(service_instance)
    end
  end

  context "when the quota is unlimited" do
    let(:total_services) { -1 }

    it "does not add errors" do
      make_service_instance
      expect(policy).to validate_without_error(service_instance)
    end
  end

  context "when the quota is reached" do
    let(:existing_service_count) { total_services }
    before { total_services.times { make_service_instance } }

    context "and the request is for a new service" do
      it "adds a service_instance_quota_exceeded error on the quota" do
        expect(policy).to validate_with_error(service_instance, :quota, error_name)
      end
    end

    context "and the request is to update an existing service" do
      let(:service_instance) do
        VCAP::CloudController::ManagedServiceInstance.first
      end

      it "allows updating the service" do
        expect(policy).to validate_without_error(service_instance)
      end

      context "and the quota is actually exceeded" do
        let(:existing_service_count) { total_services + 1 }

        it "adds an error on the quota if the quota is actually exceeded" do
          expect(policy).to validate_with_error(service_instance, :quota, error_name)
        end
      end
    end
  end
end
