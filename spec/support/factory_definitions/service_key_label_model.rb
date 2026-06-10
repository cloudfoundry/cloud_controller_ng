FactoryBot.define do
  factory :service_key_label_model, class: 'VCAP::CloudController::ServiceKeyLabelModel' do
    guid { generate(:guid) }
  end
end
