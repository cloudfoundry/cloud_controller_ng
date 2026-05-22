FactoryBot.define do
  factory :space_label_model, class: 'VCAP::CloudController::SpaceLabelModel' do
    guid { generate(:guid) }
  end
end
