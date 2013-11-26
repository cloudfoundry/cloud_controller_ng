module VCAP::CloudController
  rest_controller :QuotaDefinitions do
    define_attributes do
      attribute  :name,                       String
      attribute  :non_basic_services_allowed, Message::Boolean
      attribute  :total_services,             Integer
      attribute  :total_routes,               Integer
      attribute  :memory_limit,               Integer
      attribute  :trial_db_allowed,           Message::Boolean, :default => false
    end

    query_parameters :name

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on(:name)
      if name_errors && name_errors.include?(:unique)
        Errors::QuotaDefinitionNameTaken.new(attributes["name"])
      else
        Errors::QuotaDefinitionInvalid.new(e.errors.full_messages)
      end
    end

    def delete(guid)
      do_delete(find_guid_and_validate_access(:delete, guid))
    end
  end
end
