FactoryBot.define do
  factory :revision_sidecar_process_type_model, class: 'VCAP::CloudController::RevisionSidecarProcessTypeModel' do
    type { 'web' }
    association :revision_sidecar, factory: %i[revision_sidecar_model no_process_types]
  end
end
