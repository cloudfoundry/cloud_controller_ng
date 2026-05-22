FactoryBot.define do
  factory :process_model, aliases: [:process], class: 'VCAP::CloudController::ProcessModel' do
    instances { 1 }
    type { 'web' }
    diego { true }
    association :app, factory: :app_model
    metadata { {} }

    trait :process do
      type { generate(:name) }
    end

    trait :docker do
      association :app, factory: %i[app_model docker]
      type { generate(:name) }
    end

    trait :cnb do
      association :app, factory: %i[app_model cnb]
    end

    trait :diego_runnable do
      type { generate(:name) }
      state { 'STARTED' }
      after(:create) do |process|
        create(:droplet_model, app: process.app, set_as_current_droplet: true) unless process.app.droplet
      end
    end
  end
end
