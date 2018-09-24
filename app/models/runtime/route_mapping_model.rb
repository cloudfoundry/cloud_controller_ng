require 'cloud_controller/copilot/adapter'

module VCAP::CloudController
  class RouteMappingModel < Sequel::Model(:route_mappings)
    many_to_one :app, class: 'VCAP::CloudController::AppModel', key: :app_guid,
                      primary_key: :guid, without_guid_generation: true
    many_to_one :route, key: :route_guid, primary_key: :guid, without_guid_generation: true

    one_through_one :space, join_table: AppModel.table_name, left_key: :guid,
                            left_primary_key: :app_guid, right_primary_key: :guid, right_key: :space_guid

    many_to_one :process, class: 'VCAP::CloudController::ProcessModel',
                          key: [:app_guid, :process_type], primary_key: [:app_guid, :type]

    def validate
      validates_presence [:app_port]
      validates_unique [:app_guid, :route_guid, :process_type, :app_port]

      validate_weight
    end

    def self.user_visibility_filter(user)
      { space: Space.user_visible(user) }
    end

    def after_destroy
      super

      db.after_commit do
        Copilot::Adapter.unmap_route(self)
      end
    end

    private

    def logger
      @logger ||= Steno.logger('cc.route_mapping')
    end

    def validate_weight
      return unless weight.present?
      errors.add(:weight, 'must be between 1 and 128') unless (1..128).member?(weight)
    end
  end
end
