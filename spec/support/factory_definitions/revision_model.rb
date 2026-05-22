FactoryBot.define do
  factory :revision_model, class: 'VCAP::CloudController::RevisionModel' do
    description { 'Initial revision' }

    transient do
      app { nil }
      create_process_commands { true }
    end

    after(:build) do |revision, evaluator|
      revision.app = evaluator.app if evaluator.app
      revision.app ||= VCAP::CloudController::AppModel[guid: revision.app_guid] if revision.app_guid
      revision.app ||= create(:app_model)
      revision.droplet_guid ||= revision.app.droplet&.guid || create(:droplet_model, app: revision.app, set_as_current_droplet: false).guid
    end

    after(:create) do |revision, evaluator|
      next unless evaluator.create_process_commands

      droplet = VCAP::CloudController::DropletModel.find(guid: revision.droplet_guid)
      next if droplet.nil? || droplet.process_types.blank?

      droplet.process_types.each_key do |type|
        VCAP::CloudController::RevisionProcessCommandModel.create(
          revision: revision,
          process_type: type,
          process_command: nil
        )
      end
    end

    trait :no_commands do
      create_process_commands { false }
    end

    trait :custom_web_command do
      after(:create) do |revision, _evaluator|
        droplet = VCAP::CloudController::DropletModel.find(guid: revision.droplet_guid)
        next if droplet.nil? || droplet.process_types.blank?

        VCAP::CloudController::RevisionProcessCommandModel.where(revision_guid: revision.guid).each(&:destroy)
        droplet.process_types.each_key do |type|
          process_command = VCAP::CloudController::RevisionProcessCommandModel.create(
            revision: revision,
            process_type: type,
            process_command: nil
          )
          process_command.update(process_command: 'custom_web_command') if type == 'web'
        end
      end
    end
  end
end
