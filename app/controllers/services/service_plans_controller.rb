module VCAP::CloudController
  class ServicePlansController < RestController::ModelController
    define_attributes do
      attribute :name,              String
      attribute :free,              Message::Boolean
      attribute :description,       String
      attribute :extra,             String,           default: nil
      attribute :unique_id,         String,           default: nil
      to_one :service
      to_many :service_instances
      attribute :public, Message::Boolean, default: true
    end

    query_parameters :active, :service_guid, :service_instance_guid, :service_broker_guid
    # added :service_broker_guid here for readability, it is actually implemented as a search filter
    # in the #get_filtered_dataset_for_enumeration method because ModelControl does not support
    # searching on parameters that are not directly associated with the model

    allow_unauthenticated_access only: :enumerate
    def enumerate
      if SecurityContext.missing_token?
        single_filter = @opts[:q][0] if @opts[:q]
        service_guid = single_filter.split(':')[1] if single_filter && single_filter.start_with?('service_guid')

        plans = ServicePlan.where(active: true, public: true)
        if service_guid.present?
          services = Service.where(guid: service_guid)
          plans = plans.where(service_id: services.select(:id))
        end

        @opts.delete(:inline_relations_depth)
        collection_renderer.render_json(
          self.class,
          plans,
          self.class.path,
          @opts,
          {}
        )
      elsif SecurityContext.invalid_token?
        raise VCAP::Errors::ApiError.new_from_details('InvalidAuthToken')
      else
        super
      end
    end

    def delete(guid)
      plan = find_guid_and_validate_access(:delete, guid)

      if plan.service_instances.present?
        raise VCAP::Errors::ApiError.new_from_details('AssociationNotEmpty', 'service_instances', plan.class.table_name)
      end

      plan.destroy

      [HTTP::NO_CONTENT, nil]
    end

    def self.translate_validation_exception(e, attributes)
      name_errors = e.errors.on([:service_id, :name])
      if name_errors && name_errors.include?(:unique)
        Errors::ApiError.new_from_details('ServicePlanNameTaken', "#{attributes['service_id']}-#{attributes['name']}")
      else
        Errors::ApiError.new_from_details('ServicePlanInvalid', e.errors.full_messages)
      end
    end

    def get_filtered_dataset_for_enumeration(model, ds, qp, opts)
      single_filter = opts[:q][0] if opts[:q]

      if single_filter && single_filter.start_with?('service_broker_guid')
        service_broker_guid = single_filter.split(':')[1]

        Query.
          filtered_dataset_from_query_params(model, ds, qp, { q: '' }).
          select_all(:service_plans).
          left_join(:services, id: :service_plans__service_id).
          left_join(:service_brokers, id: :services__service_broker_id).
          where(service_brokers__guid: service_broker_guid)
      else
        super(model, ds, qp, opts)
      end
    end

    define_messages
    define_routes
  end
end
