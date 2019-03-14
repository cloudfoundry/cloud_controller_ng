require 'models/runtime/build_model'

FactoryBot.define do
  factory :build, class: VCAP::CloudController::BuildModel do
    guid
    app
    state { VCAP::CloudController::BuildModel::STAGED_STATE }

    trait :docker do
      state { VCAP::CloudController::BuildModel::STAGING_STATE }

      after(:create) do |build, evaluator|
        build.buildpack_lifecycle_data = nil
      end
    end
  end
end
