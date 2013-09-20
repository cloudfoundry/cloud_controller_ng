module VCAP::CloudController
  rest_controller :Routes do
    define_attributes do
      attribute :host, String, :default => ""
      to_one    :domain
      to_one    :space
      to_many   :apps
    end

    query_parameters :host, :domain_guid

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on([:host, :domain_id])
      if name_errors && name_errors.include?(:unique)
        Errors::RouteHostTaken.new(attributes["host"])
      else
        Errors::RouteInvalid.new(e.errors.full_messages)
      end
    end
  end
end
