require 'ext/validation_error_message_overrides'

module VCAP::CloudController
  class ServicesController < RestController::ModelController
    define_attributes do
      attribute :label,             String
      attribute :description,       String
      attribute :long_description,  String, :default => nil
      attribute :info_url,          Message::URL, :default => nil
      attribute :documentation_url, Message::URL, :default => nil
      attribute :acls,              {"users" => [String], "wildcards" => [String]}, :default => nil
      attribute :timeout,           Integer, :default => nil
      attribute :active,            Message::Boolean, :default => false
      attribute :bindable,          Message::Boolean, :default => true
      attribute :extra,             String, :default => nil
      attribute :unique_id,         String, :default => nil
      attribute :tags,              [String], :default => []
      attribute :requires,          [String], :default => []

      # NOTE: DEPRECATED
      #
      # These attributes are required for V1 service providers only. The
      # constraints have been relaxed on the model and the table to allow
      # V2 service providers to register services without them.
      #
      # Since this controller is the only way for a V1 provider to register
      # services, these requirements are needed until support for V1
      # providers is officially dropped.
      attribute :provider,          String
      attribute :version,           String
      attribute :url,               Message::URL

      to_many   :service_plans
    end

    query_parameters :active, :label, :provider, :service_broker_guid

    allow_unauthenticated_access only: :enumerate
    def enumerate
      @opts.delete(:inline_relations_depth) unless SecurityContext.valid_token?
      super
    end

    def self.translate_validation_exception(e, attributes)
      label_provider_errors = e.errors.on([:label, :provider])
      if label_provider_errors && label_provider_errors.include?(:unique)
        Errors::ApiError.new_from_details("ServiceLabelTaken", "#{attributes["label"]}-#{attributes["provider"]}")
      else
        Errors::ApiError.new_from_details("ServiceInvalid", e.errors.full_messages)
      end
    end

    def delete(guid)
      service = find_guid_and_validate_access(:delete, guid)
      if purge?
        service.purge
        [HTTP::NO_CONTENT, nil]
      else
        do_delete(find_guid_and_validate_access(:delete, guid))
      end
    end

    define_messages
    define_routes

    private

    def purge?
      params['purge'] == 'true'
    end
  end
end
