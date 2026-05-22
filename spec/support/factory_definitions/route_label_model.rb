FactoryBot.define do
  factory :route_label_model, class: 'VCAP::CloudController::RouteLabelModel' do
    guid { generate(:guid) }
  end
end
