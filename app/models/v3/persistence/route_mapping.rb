module VCAP::CloudController
  class RouteMappingModel < Sequel::Model(:route_mappings)
    many_to_one :app, class: 'VCAP::CloudController::AppModel', key: :app_guid, primary_key: :guid, without_guid_generation: true
    many_to_one :route, key: :route_guid, primary_key: :guid, without_guid_generation: true

    one_through_one :space, join_table: AppModel.table_name, left_key: :guid, left_primary_key: :app_guid, right_primary_key: :guid, right_key: :space_guid

    def validate
      validates_unique [:app_guid, :route_guid, :process_type]
    end
  end
end
