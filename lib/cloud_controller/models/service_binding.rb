# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::Models
  class ServiceBinding < Sequel::Model
    class InvalidAppAndServiceRelation < StandardError; end

    many_to_one :app, :before_set => :validate_app
    many_to_one :service_instance, :before_set => :validate_service_instance

    default_order_by  :id

    export_attributes :app_guid, :service_instance_guid, :credentials,
                      :binding_options, :vendor_data

    import_attributes :app_guid, :service_instance_guid, :credentials,
                      :binding_options, :vendor_data

    def validate
      validates_presence :app
      validates_presence :service_instance
      validates_presence :credentials
      validates_unique [:app_id, :service_instance_id]
    end

    def validate_app_and_service_instance(app, service_instance)
      if app && service_instance
        unless service_instance.app_space == app.app_space
          raise InvalidAppAndServiceRelation.new(
            "'#{app.app_space.name}' '#{service_instance.app_space.name}'")
        end
      end
    end

    def validate_app(app)
      validate_app_and_service_instance(app, service_instance)
    end

    def validate_service_instance(service_instance)
      validate_app_and_service_instance(app, service_instance)
    end

    def app_space
      service_instance.app_space
    end
  end
end
