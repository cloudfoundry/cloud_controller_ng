FactoryBot.define do
  factory :package_model, class: 'VCAP::CloudController::PackageModel' do
    guid { generate(:guid) }
    state { VCAP::CloudController::PackageModel::CREATED_STATE }
    type { 'bits' }
    association :app, factory: :app_model
    sha256_checksum { generate(:guid) }

    trait :buildpack do
    end

    trait :docker do
      state { VCAP::CloudController::PackageModel::READY_STATE }
      type { 'docker' }
      docker_image { "org/image-#{generate(:guid)}:latest" }
      sha256_checksum { nil }
    end

    trait :cnb do
      association :app, factory: %i[app_model cnb]
    end
  end
end
