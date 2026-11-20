FactoryBot.define do
  factory :app_model, class: 'VCAP::CloudController::AppModel' do
    name { generate(:name) }
    association :space

    transient do
      lifecycle { :buildpack }
    end

    lifecycle_type do
      case lifecycle
      when :buildpack then VCAP::CloudController::BuildpackLifecycleDataModel::LIFECYCLE_TYPE
      when :cnb then VCAP::CloudController::CNBLifecycleDataModel::LIFECYCLE_TYPE
      when :docker then VCAP::CloudController::DockerLifecycleDataModel::LIFECYCLE_TYPE
      end
    end

    after(:create) do |app, evaluator|
      case evaluator.lifecycle
      when :buildpack
        VCAP::CloudController::BuildpackLifecycleDataModel.create(app: app, buildpacks: nil, stack: create(:stack).name)
      when :cnb
        VCAP::CloudController::CNBLifecycleDataModel.create(app: app, buildpacks: nil, stack: create(:stack).name)
      end
      app.reload
    end

    trait :buildpack do
      lifecycle { :buildpack }
    end

    trait :docker do
      lifecycle { :docker }
    end

    trait :cnb do
      lifecycle { :cnb }
    end

    # For specs that create the lifecycle data themselves (e.g.
    # #create_lifecycle_data_model); avoids a colliding pre-existing row.
    trait :no_lifecycle_data do
      lifecycle_type { VCAP::CloudController::BuildpackLifecycleDataModel::LIFECYCLE_TYPE }
      lifecycle { :none }
    end

    trait :all_fields do
      association :droplet, factory: :droplet_model
      buildpack_cache_sha256_checksum { generate(:guid) }
    end
  end
end
