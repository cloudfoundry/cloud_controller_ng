require 'models/runtime/package_model'

FactoryBot.define do
  factory :package, aliases: [:package_model], class: VCAP::CloudController::PackageModel do
    guid
    app

    state { VCAP::CloudController::PackageModel::CREATED_STATE }
    type { 'bits' }

    trait :docker do
      state { VCAP::CloudController::PackageModel::READY_STATE }
      type { 'docker' }
      docker_image { "org/image-#{Sham.guid}:latest" }
    end
  end
end
