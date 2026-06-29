FactoryBot.define do
  factory :task_model, class: 'VCAP::CloudController::TaskModel' do
    guid { generate(:guid) }
    association :app, factory: :app_model
    name { generate(:name) }
    command { 'bundle exec rake' }
    state { VCAP::CloudController::TaskModel::RUNNING_STATE }
    memory_in_mb { 256 }
    sequence_id { generate(:sequence_id) }

    transient do
      skip_default_droplet { false }
    end

    after(:build) do |task, evaluator|
      task.droplet ||= create(:droplet_model, app: task.app, set_as_current_droplet: false) unless evaluator.skip_default_droplet
    end

    trait :docker do
      association :app, factory: %i[app_model docker]
      after(:build) do |task|
        task.droplet = create(:droplet_model, :docker, app: task.app, set_as_current_droplet: false) unless task.droplet&.docker?
      end
    end

    trait :cnb do
      association :app, factory: %i[app_model cnb]
      after(:build) do |task|
        task.droplet = create(:droplet_model, :cnb, app: task.app, set_as_current_droplet: false) unless task.droplet&.cnb?
      end
    end

    trait :running do
      state { VCAP::CloudController::TaskModel::RUNNING_STATE }
    end

    trait :canceling do
      state { VCAP::CloudController::TaskModel::CANCELING_STATE }
    end

    trait :succeeded do
      state { VCAP::CloudController::TaskModel::SUCCEEDED_STATE }
    end

    trait :pending do
      state { VCAP::CloudController::TaskModel::PENDING_STATE }
    end
  end
end
