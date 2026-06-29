FactoryBot.define do
  factory :revision_process_command_model, class: 'VCAP::CloudController::RevisionProcessCommandModel' do
    process_type { 'web' }
    process_command { '$HOME/boot.sh' }
    association :revision, factory: %i[revision_model no_commands]
  end
end
