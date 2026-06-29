FactoryBot.define do
  factory :process_label_model, class: 'VCAP::CloudController::ProcessLabelModel' do
    guid { generate(:guid) }
  end
end
