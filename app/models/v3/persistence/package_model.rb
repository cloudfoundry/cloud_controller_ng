module VCAP::CloudController
  class PackageModel < Sequel::Model(:packages)
    PACKAGE_STATES = [
      PENDING_STATE = 'PROCESSING_UPLOAD'.freeze,
      READY_STATE   = 'READY'.freeze,
      FAILED_STATE  = 'FAILED'.freeze,
      CREATED_STATE = 'AWAITING_UPLOAD'.freeze,
      COPYING_STATE = 'COPYING'.freeze,
      EXPIRED_STATE = 'EXPIRED'.freeze
    ].map(&:freeze).freeze

    PACKAGE_TYPES = [
      BITS_TYPE   = 'bits'.freeze,
      DOCKER_TYPE = 'docker'.freeze
    ].map(&:freeze).freeze

    one_to_many :droplets, class: 'VCAP::CloudController::DropletModel', key: :package_guid, primary_key: :guid
    many_to_one :app, class: 'VCAP::CloudController::AppModel', key: :app_guid, primary_key: :guid, without_guid_generation: true
    one_through_one :space, join_table: AppModel.table_name, left_key: :guid, left_primary_key: :app_guid, right_primary_key: :guid, right_key: :space_guid

    one_to_one :docker_data,
      class: 'VCAP::CloudController::PackageDockerDataModel',
      key: :package_guid,
      primary_key: :guid

    def validate
      validates_includes PACKAGE_STATES, :state, allow_missing: true
      errors.add(:type, 'cannot have docker data if type is bits') if docker_data && type != DOCKER_TYPE
    end

    def self.user_visible(user)
      dataset.
        join(AppModel.table_name, :"#{AppModel.table_name}__guid" => :"#{PackageModel.table_name}__app_guid").
        where(AppModel.user_visibility_filter(user)).
        select_all(PackageModel.table_name)
    end
  end
end
