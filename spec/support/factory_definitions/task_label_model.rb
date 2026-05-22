FactoryBot.define do
  factory :task_label_model, class: 'VCAP::CloudController::TaskLabelModel' do
    guid { generate(:guid) }
  end
end
