FactoryBot.define do
  factory :build_model, class: 'VCAP::CloudController::BuildModel' do
    guid { generate(:guid) }
    association :app, factory: :app_model
    state { VCAP::CloudController::BuildModel::STAGED_STATE }

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

    after(:create) do |build, evaluator|
      case evaluator.lifecycle
      when :buildpack
        build.buildpack_lifecycle_data = VCAP::CloudController::BuildpackLifecycleDataModel.create(build: build, buildpacks: nil, stack: create(:stack).name)
      when :cnb
        build.cnb_lifecycle_data = VCAP::CloudController::CNBLifecycleDataModel.create(build: build, buildpacks: nil, stack: create(:stack).name)
      end
    end

    trait :docker do
      lifecycle { :docker }
      state { VCAP::CloudController::BuildModel::STAGING_STATE }
      association :app, factory: %i[app_model docker]
    end

    trait :cnb do
      lifecycle { :cnb }
      state { VCAP::CloudController::BuildModel::STAGING_STATE }
      association :app, factory: %i[app_model cnb]
    end
  end
end
