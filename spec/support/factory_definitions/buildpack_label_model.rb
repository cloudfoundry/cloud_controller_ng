FactoryBot.define do
  factory :buildpack_label_model, class: 'VCAP::CloudController::BuildpackLabelModel' do
    guid { generate(:guid) }
  end
end
