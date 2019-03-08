require 'models/runtime/app_model'

FactoryBot.define do
  factory :app, aliases: [:app_model], class: VCAP::CloudController::AppModel do
    to_create(&:save)

    name

    transient do
      space
    end

    trait :buildpack do
      after(:create) do |app, evaluator|
        app.buildpack_lifecycle_data = create(:buildpack_lifecycle_data)
      end
    end

    trait :docker do
    end

    after(:create) do |app, evaluator|
      app.space = evaluator.space if evaluator.space
    end
  end
end
