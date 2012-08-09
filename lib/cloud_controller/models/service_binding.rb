# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class ServiceBinding < Sequel::Model
    class InvalidAppAndServiceRelation < StandardError; end

    many_to_one :app
    many_to_one :service_instance

    default_order_by  :id

    export_attributes :app_guid, :service_instance_guid, :credentials,
                      :binding_options, :gateway_data

    import_attributes :app_guid, :service_instance_guid, :credentials,
                      :binding_options, :gateway_data

    def validate
      # we can't use validates_presence because it ends up using the
      # credentials method below and looks at the hash, which can be empty..
      # and that isn't the same thing as nil for us
      errors.add(:credentials, :presence) if credentials.nil?

      validates_presence :app
      validates_presence :service_instance
      validates_unique [:app_id, :service_instance_id]

      # TODO: make this a standard validation
      validate_app_and_service_instance(app, service_instance)
    end

    def validate_app_and_service_instance(app, service_instance)
      if app && service_instance
        unless service_instance.space == app.space
          raise InvalidAppAndServiceRelation.new(
            "'#{app.space.name}' '#{service_instance.space.name}'")
        end
      end
    end

    def space
      service_instance.space
    end

    def after_create
      mark_app_for_restaging
    end

    def after_update
      mark_app_for_restaging
    end

    def before_destroy
      mark_app_for_restaging
    end

    def mark_app_for_restaging
      app.mark_for_restaging if app
    end

    def self.user_visibility_filter(user)
      user_visibility_filter_with_admin_override(
        :service_instance => ServiceInstance.user_visible)
    end

    def credentials=(val)
      val = Yajl::Encoder.encode(val)
      super(val)
    end

    def credentials
      val = super
      val = Yajl::Parser.parse(val) if val
      val
    end
  end
end
