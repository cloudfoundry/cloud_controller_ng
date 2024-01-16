module VCAP::CloudController
  class BuildDelete
    def initialize(cancel_action)
      @cancel_action = cancel_action
    end

    def delete_for_app(guid)
      builds_in_staging_state = BuildModel.where(app_guid: guid, state: BuildModel::STAGING_STATE).all
      @cancel_action.cancel(builds_in_staging_state)

      BuildModel.where(app_guid: guid).delete
    end
  end
end
