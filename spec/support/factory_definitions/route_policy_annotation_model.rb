FactoryBot.define do
  factory :route_policy_annotation_model, class: 'VCAP::CloudController::RoutePolicyAnnotationModel' do
    guid { generate(:guid) }
    resource_guid { create(:route_policy).guid }
    key_name { 'key' }
    value { 'value' }
  end
end
