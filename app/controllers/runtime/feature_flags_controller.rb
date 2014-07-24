module VCAP::CloudController
  class FeatureFlagsController < RestController::ModelController
    def self.path
      "#{ROUTE_PREFIX}/config/feature_flags"
    end

    def self.translate_validation_exception(e, attributes)
      Errors::ApiError.new_from_details("FeatureFlagInvalid", e.errors.full_messages)
    end

    get path, :enumerate

    put "#{path}/:name", :update_feature_flag
    def update_feature_flag(name)
      raise Errors::ApiError.new_from_details("NotAuthorized") unless roles.admin?

      feature_flag = FeatureFlag.find(:name => name)
      raise self.class.not_found_exception(name) if feature_flag.nil?

      feature_flag_attributes = MultiJson.load(body)
      feature_flag.update(:enabled => feature_flag_attributes["enabled"])
      [
        HTTP::OK,
        object_renderer.render_json(self.class, feature_flag, @opts)
      ]
    end

    private

    def enumerate
      raise Errors::ApiError.new_from_details("NotAuthorized") unless roles.admin?
      super
    end
  end
end
