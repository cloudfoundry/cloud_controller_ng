FactoryBot.define do
  factory :buildpack_lifecycle_data_model, class: 'VCAP::CloudController::BuildpackLifecycleDataModel' do
    buildpacks { nil }
    stack { create(:stack).name }

    trait :all_fields do
      buildpacks { ['http://example.com/repo.git'] }
      stack { create(:stack).name }
      app_guid { generate(:guid) }
      association :droplet, factory: :droplet_model
      admin_buildpack_name { 'admin-bp' }
      association :build, factory: :build_model
    end
  end
end
