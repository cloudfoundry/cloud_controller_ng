module VCAP::CloudController
  class BuildModel < Sequel::Model(:builds)
    BUILD_STATES = [
      STAGING_STATE = 'STAGING'.freeze,
      STAGED_STATE = 'STAGED'.freeze,
      FAILED_STATE = 'FAILED'.freeze,
    ].freeze

    many_to_one :app,
      class: 'VCAP::CloudController::AppModel',
      key: :app_guid,
      primary_key: :guid,
      without_guid_generation: true
    one_to_one :droplet,
      class: 'VCAP::CloudController::DropletModel',
      key: :build_guid,
      primary_key: :guid
    many_to_one :package,
      class: 'VCAP::CloudController::PackageModel',
      key: :package_guid,
      primary_key: :guid,
      without_guid_generation: true
    one_to_one :buildpack_lifecycle_data,
      class:       'VCAP::CloudController::BuildpackLifecycleDataModel',
      key:         :build_guid,
      primary_key: :guid

    add_association_dependencies buildpack_lifecycle_data: :delete

    def lifecycle_type
      return BuildpackLifecycleDataModel::LIFECYCLE_TYPE if buildpack_lifecycle_data
      DockerLifecycleDataModel::LIFECYCLE_TYPE
    end

    def lifecycle_data
      return buildpack_lifecycle_data if buildpack_lifecycle_data
      DockerLifecycleDataModel.new
    end

    def staged?
      self.state == STAGED_STATE
    end

    def failed?
      self.state == FAILED_STATE
    end

    def staging?
      self.state == STAGING_STATE
    end
  end
end
