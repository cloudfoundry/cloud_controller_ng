FactoryBot.define do
  factory :droplet_model, class: 'VCAP::CloudController::DropletModel' do
    guid { generate(:guid) }
    process_types { { 'web' => '$HOME/boot.sh' } }
    state { VCAP::CloudController::DropletModel::STAGED_STATE }
    droplet_hash { generate(:guid) }
    sha256_checksum { generate(:guid) }

    transient do
      app { :unset }
      lifecycle { :buildpack }
      set_as_current_droplet { app == :unset }
    end

    lifecycle_type do
      case lifecycle
      when :buildpack then VCAP::CloudController::BuildpackLifecycleDataModel::LIFECYCLE_TYPE
      when :cnb then VCAP::CloudController::CNBLifecycleDataModel::LIFECYCLE_TYPE
      when :docker then VCAP::CloudController::DockerLifecycleDataModel::LIFECYCLE_TYPE
      end
    end

    after(:build) do |droplet, evaluator|
      if evaluator.app == :unset
        droplet.app ||= VCAP::CloudController::AppModel[guid: droplet.app_guid] if droplet.app_guid
        droplet.app ||= create(:app_model)
      else
        droplet.app = evaluator.app
      end
    end

    after(:create) do |droplet, evaluator|
      droplet.app.update(droplet:) if droplet.app && evaluator.set_as_current_droplet && droplet.state == VCAP::CloudController::DropletModel::STAGED_STATE
      case evaluator.lifecycle
      when :buildpack
        VCAP::CloudController::BuildpackLifecycleDataModel.create(droplet: droplet, buildpacks: nil, stack: create(:stack).name)
        droplet.reload
      when :cnb
        VCAP::CloudController::CNBLifecycleDataModel.create(droplet: droplet, buildpacks: nil, stack: create(:stack).name)
        droplet.reload
      end
      droplet.associations.delete(:buildpack_lifecycle_data)
      droplet.associations.delete(:cnb_lifecycle_data)
    end

    trait :buildpack do
      lifecycle { :buildpack }
    end

    trait :docker do
      droplet_hash { nil }
      sha256_checksum { nil }
      process_types { nil }
      lifecycle { :docker }
    end

    trait :cnb do
      lifecycle { :cnb }
    end

    trait :all_fields do
      execution_metadata { 'some-metadata' }
      error_id { 'error-id' }
      error_description { 'a-error' }
      staging_memory_in_mb { 256 }
      staging_disk_in_mb { 256 }
      buildpack_receipt_buildpack { 'a-buildpack' }
      buildpack_receipt_buildpack_guid { generate(:guid) }
      buildpack_receipt_detect_output { 'buildpack-output' }
      docker_receipt_image { 'docker-image' }
      package_guid { generate(:guid) }
      build_guid { generate(:guid) }
      docker_receipt_username { 'a-user' }
      sidecars { 'a-sidecar' }
    end
  end
end
