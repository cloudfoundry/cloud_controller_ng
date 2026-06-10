FactoryBot.define do
  factory :app_label_model, class: 'VCAP::CloudController::AppLabelModel' do
    guid { generate(:guid) }
  end
end
