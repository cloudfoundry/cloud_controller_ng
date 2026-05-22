FactoryBot.define do
  factory :package_label_model, class: 'VCAP::CloudController::PackageLabelModel' do
    guid { generate(:guid) }
  end
end
