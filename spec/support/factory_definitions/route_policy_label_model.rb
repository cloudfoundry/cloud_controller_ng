FactoryBot.define do
  factory :route_policy_label_model, class: 'VCAP::CloudController::RoutePolicyLabelModel' do
    guid { generate(:guid) }
    resource_guid { create(:route_policy).guid }
    key_name { 'key' }
    value { 'value' }
  end
end
