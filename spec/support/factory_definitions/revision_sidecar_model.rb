FactoryBot.define do
  factory :revision_sidecar_model, class: 'VCAP::CloudController::RevisionSidecarModel' do
    name    { 'sleepy' }
    command { 'sleep infinity' }
    association :revision, factory: :revision_model

    transient do
      create_process_types { true }
    end

    after(:create) do |sidecar, evaluator|
      next unless evaluator.create_process_types

      create(:revision_sidecar_process_type_model, revision_sidecar: sidecar) if sidecar.revision_sidecar_process_types.empty?
      sidecar.refresh
    end

    trait :no_process_types do
      create_process_types { false }
    end
  end
end
