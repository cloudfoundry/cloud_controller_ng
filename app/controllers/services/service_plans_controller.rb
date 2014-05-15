module VCAP::CloudController
  class ServicePlansController < RestController::ModelController
    define_attributes do
      attribute :name,              String
      attribute :free,              Message::Boolean
      attribute :description,       String
      attribute :extra,             String,           default: nil
      attribute :unique_id,         String,           default: nil
      to_one    :service
      to_many   :service_instances
      attribute :public, Message::Boolean, default: true
      #attribute :active, Message::Boolean, default: true
    end

    query_parameters :active, :service_guid, :service_instance_guid

    allow_unauthenticated_access only: :enumerate
    def enumerate
      return super if SecurityContext.valid_token?
      plans = ServicePlan.where(active: true, public: true)

      @opts.delete(:inline_relations_depth)
      collection_renderer.render_json(
        self.class,
        plans,
        self.class.path,
        @opts,
        {}
      )
    end

    # Override this method because we want to enable the concept of
    # deleted apps. This is necessary because we have an app events table
    # which is a foreign key constraint on apps. Thus, we can't actually delete
    # the app itself, but instead mark it as deleted.
    #
    # @param [String] guid The GUID of the object to delete.
    def delete(guid)
      plan = find_guid_and_validate_access(:delete, guid)

      if plan.service_instances.present?
        raise VCAP::Errors::ApiError.new_from_details("AssociationNotEmpty", "service_instances", plan.class.table_name)
      end

      plan.destroy

      [ HTTP::NO_CONTENT, nil ]
    end

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on([:service_id, :name])
      if name_errors && name_errors.include?(:unique)
        Errors::ApiError.new_from_details("ServicePlanNameTaken", "#{attributes["service_id"]}-#{attributes["name"]}")
      else
        Errors::ApiError.new_from_details("ServicePlanInvalid", e.errors.full_messages)
      end
    end

    define_messages
    define_routes
  end
end
