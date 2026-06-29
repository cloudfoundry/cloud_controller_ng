FactoryBot.define do
  factory :service_plan_visibility, class: 'VCAP::CloudController::ServicePlanVisibility' do
    service_plan { create(:service_plan, public: false) } # rubocop:disable FactoryBot/FactoryAssociationWithStrategy
    association :organization
  end
end
