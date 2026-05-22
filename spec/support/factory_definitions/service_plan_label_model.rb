FactoryBot.define do
  factory :service_plan_label_model, class: 'VCAP::CloudController::ServicePlanLabelModel' do
    guid { generate(:guid) }
  end
end
