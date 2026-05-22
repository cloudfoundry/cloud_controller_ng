FactoryBot.define do
  factory :organization_label_model, class: 'VCAP::CloudController::OrganizationLabelModel' do
    guid { generate(:guid) }
  end
end
