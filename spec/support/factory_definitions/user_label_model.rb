FactoryBot.define do
  factory :user_label_model, class: 'VCAP::CloudController::UserLabelModel' do
    guid { generate(:guid) }
  end
end
