FactoryBot.define do
  factory :stack_label_model, class: 'VCAP::CloudController::StackLabelModel' do
    guid { generate(:guid) }
  end
end
