module VCAP::CloudController
  class FeatureFlagsController < RestController::ModelController
    def self.path
      "#{ROUTE_PREFIX}/config/feature_flags"
    end

    def self.translate_validation_exception(e, attributes)
      Errors::ApiError.new_from_details('FeatureFlagInvalid', e.errors.full_messages)
    end

    get path, :enumerate
    def enumerate
      validate_access(:index, model, user, roles)

      db_feature_flags = {}
      FeatureFlag.all.each { |feature| db_feature_flags[feature.name.to_sym] = feature.enabled }

      feature_flags = FeatureFlag::DEFAULT_FLAGS.keys.map do |key|
        default_value = FeatureFlag::DEFAULT_FLAGS[key]
        current_value = db_feature_flags.fetch(key, default_value)

        {
          name:          key.to_s,
          enabled:       current_value,
          default_value: default_value,
          url:           "#{FeatureFlagsController.path}/#{key.to_s}",
        }
      end

      [
        HTTP::OK,
        MultiJson.dump(feature_flags, pretty: true)
      ]
    end

    get "#{path}/:name", :read
    def read(name)
      validate_access(:read, model, user, roles)

      raise self.class.not_found_exception(name) unless FeatureFlag::DEFAULT_FLAGS.has_key?(name.to_sym)

      response = {
        name:          name,
        enabled:       FeatureFlag::DEFAULT_FLAGS[name.to_sym],
        default_value: FeatureFlag::DEFAULT_FLAGS[name.to_sym],
        url:           "#{FeatureFlagsController.path}/#{name}",
      }

      feature_flag = FeatureFlag.find(name: name)
      response[:enabled] = feature_flag.enabled if feature_flag

      [
        HTTP::OK,
        MultiJson.dump(response, pretty: true)
      ]
    end

    put "#{path}/:name", :update_feature_flag
    def update_feature_flag(name)
      validate_access(:update, model, user, roles)

      raise self.class.not_found_exception(name) unless FeatureFlag::DEFAULT_FLAGS.has_key?(name.to_sym)

      feature_flag_attributes = MultiJson.load(body)

      feature_flag = FeatureFlag.find(name: name)
      feature_flag ||= FeatureFlag.new(name: name)

      feature_flag.enabled = feature_flag_attributes['enabled']
      feature_flag.save

      [
        HTTP::OK,
        MultiJson.dump(
          {
            name:          feature_flag.name,
            enabled:       feature_flag.enabled,
            default_value: FeatureFlag::DEFAULT_FLAGS[feature_flag.name.to_sym],
            url:           "#{FeatureFlagsController.path}/#{feature_flag.name}",
          }, pretty: true)
      ]
    end
  end
end
