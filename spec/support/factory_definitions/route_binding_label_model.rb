FactoryBot.define do
  factory :route_binding_label_model, class: 'VCAP::CloudController::RouteBindingLabelModel' do
    guid { generate(:guid) }
  end
end
