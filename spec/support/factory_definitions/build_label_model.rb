FactoryBot.define do
  factory :build_label_model, class: 'VCAP::CloudController::BuildLabelModel' do
    guid { generate(:guid) }
  end
end
