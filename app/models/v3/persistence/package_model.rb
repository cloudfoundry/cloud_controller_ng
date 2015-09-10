module VCAP::CloudController
  class PackageModel < Sequel::Model(:packages)
    PACKAGE_STATES = [
      PENDING_STATE = 'PROCESSING_UPLOAD',
      READY_STATE   = 'READY',
      FAILED_STATE  = 'FAILED',
      CREATED_STATE = 'AWAITING_UPLOAD',
      COPYING_STATE = 'COPYING'
    ].map(&:freeze).freeze

    PACKAGE_TYPES = [
      BITS_TYPE   = 'bits',
      DOCKER_TYPE = 'docker'
    ].map(&:freeze).freeze

    many_to_one :app, class: 'VCAP::CloudController::AppModel', key: :app_guid, primary_key: :guid, without_guid_generation: true
    one_through_one :space, join_table: AppModel.table_name, left_key: :guid, left_primary_key: :app_guid, right_primary_key: :guid, right_key: :space_guid

    def validate
      validates_includes PACKAGE_STATES, :state, allow_missing: true
    end

    def self.user_visible(user)
      dataset.
        join(AppModel.table_name, :"#{AppModel.table_name}__guid" => :"#{PackageModel.table_name}__app_guid").
        where(AppModel.user_visibility_filter(user)).
        select_all(PackageModel.table_name)
    end

    def stage_with_diego?
      false
    end
  end
end
