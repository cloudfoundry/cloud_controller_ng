FactoryBot.define do
  factory :service_plan_annotation_model, class: 'VCAP::CloudController::ServicePlanAnnotationModel' do
    guid { generate(:guid) }
  end
end
