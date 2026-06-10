FactoryBot.define do
  factory :revision_label_model, class: 'VCAP::CloudController::RevisionLabelModel' do
    guid { generate(:guid) }
  end
end
