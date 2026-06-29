FactoryBot.define do
  factory :buildpack_lifecycle_buildpack_model, class: 'VCAP::CloudController::BuildpackLifecycleBuildpackModel' do
    admin_buildpack_name { create(:buildpack).name }
    buildpack_url        { nil }

    trait :all_fields do
      buildpack_lifecycle_data_guid { create(:buildpack_lifecycle_data_model).guid }
      version { generate(:version) }
      buildpack_name { generate(:name) }
    end

    trait :custom_buildpack do
      admin_buildpack_name { nil }
      buildpack_url { 'http://example.com/temporary' }
    end
  end
end
