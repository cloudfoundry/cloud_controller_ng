FactoryBot.define do
  factory :cnb_lifecycle_data_model, class: 'VCAP::CloudController::CNBLifecycleDataModel' do
    buildpacks { nil }
    stack { create(:stack).name }

    trait :all_fields do
      buildpacks { ['docker://docker.io/paketobuildpacks/nodejs'] }
      stack { create(:stack).name }
      app_guid { generate(:guid) }
      association :droplet, factory: :droplet_model
      association :build, factory: :build_model
    end
  end
end
