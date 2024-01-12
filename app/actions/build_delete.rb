module VCAP::CloudController
  class BuildDelete
    def initialize(cancel_action)
      @cancel_action = cancel_action
    end

    def delete_for_app(guid)
      builds_in_staging_state = BuildModel.where(app_guid: guid, state: BuildModel::STAGING_STATE).all
      @cancel_action.cancel(builds_in_staging_state)

      BuildModel.db.transaction do
        app_builds_dataset = BuildModel.where(app_guid: guid)
        BuildpackLifecycleBuildpackModel.where(
          buildpack_lifecycle_data_guid: BuildpackLifecycleDataModel.join(
            :builds, guid: :build_guid
          ).where(
            builds__app_guid: guid
          ).select(:buildpack_lifecycle_data__guid)
        ).delete
        BuildpackLifecycleDataModel.where(build_guid: app_builds_dataset.select(:guid)).delete
        KpackLifecycleDataModel.where(build_guid: app_builds_dataset.select(:guid)).delete
        BuildLabelModel.where(resource_guid: app_builds_dataset.select(:guid)).delete
        BuildAnnotationModel.where(resource_guid: app_builds_dataset.select(:guid)).delete
        app_builds_dataset.delete
      end
    end
  end
end
