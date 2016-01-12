module VCAP::CloudController
  class RouteMappingsController < RestController::ModelController
    define_attributes do
      to_one :app, exclude_in: [:update]
      to_one :route, exclude_in: [:update]
      attribute :app_port, Integer, default: nil
    end

    post path, :create
    def before_create
      # app_guid = @request_attrs['app_guid']
      # app = App.find(guid: app_guid)
      # raise Errors::ApiError.new_from_details('AppNotFound', app_guid) unless app
      #
      #
      # if !request_attrs['app_port'] && app.diego
      #   @request_attrs = @request_attrs.deep_dup
      #   @request_attrs['app_port'] = app.ports.first
      #   @request_attrs.freeze
      # end
      super
    end


    def self.translate_validation_exception(e, attributes)
    end

    # def delete(guid)
    #   do_delete(find_guid_and_validate_access(:delete, guid))
    # end

    define_messages
  end
end
