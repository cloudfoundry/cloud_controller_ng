module VCAP::CloudController
  class SpaceQuotaDefinitionsController < RestController::ModelController
    define_attributes do
      attribute :name,                       String
      attribute :non_basic_services_allowed, Message::Boolean
      attribute :total_services,             Integer
      attribute :total_service_keys,         Integer, default: -1
      attribute :total_routes,               Integer
      attribute :memory_limit,               Integer
      attribute :instance_memory_limit,      Integer, default: nil
      attribute :app_instance_limit,         Integer, default: nil
      attribute :app_task_limit,             Integer, default: 5
      attribute :total_reserved_route_ports, Integer, default: -1

      to_one :organization
      to_many :spaces, exclude_in: %i[create update]
    end

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on(%i[organization_id name])
      if name_errors && name_errors.include?(:unique)
        CloudController::Errors::ApiError.new_from_details('SpaceQuotaDefinitionNameTaken', attributes['name'])
      else
        CloudController::Errors::ApiError.new_from_details('SpaceQuotaDefinitionInvalid', e.errors.full_messages)
      end
    end

    def before_update(quota)
      if request_attrs['space'] && quota.log_rate_limit != QuotaDefinition::UNLIMITED
        affected_processes = Space.dataset.
                             join(:apps, space_guid: :guid).
                             join(:processes, app_guid: :guid).
                             where(Sequel[:spaces][:guid] => request_attrs['space'])

        unless affected_processes.where(log_rate_limit: ProcessModel::UNLIMITED_LOG_RATE).empty?
          raise CloudController::Errors::ApiError.new_from_details(
            'UnprocessableEntity',
            'Current usage exceeds new quota values. This space currently contains apps running with an unlimited log rate limit.'
          )
        end
      end

      super(quota)
    end

    def delete(guid)
      do_delete(find_guid_and_validate_access(:delete, guid))
    end

    define_messages
    define_routes
  end
end
