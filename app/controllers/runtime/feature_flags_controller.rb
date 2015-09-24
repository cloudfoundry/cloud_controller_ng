require 'presenters/api/feature_flag_presenter'

module VCAP::CloudController
  class FeatureFlagsController < RestController::ModelController
    def self.path
      "#{V2_ROUTE_PREFIX}/config/feature_flags"
    end

    def self.translate_validation_exception(e, attributes)
      Errors::ApiError.new_from_details('FeatureFlagInvalid', e.errors.full_messages)
    end

    get path, :enumerate
    def enumerate
      validate_access(:index, model)

      db_feature_flags = {}
      FeatureFlag.all.each { |feature| db_feature_flags[feature.name.to_sym] = feature }

      feature_flags = FeatureFlag::DEFAULT_FLAGS.keys.map do |key|
        feature_flag = db_feature_flags[key]

        FeatureFlagPresenter.new(feature_flag, key, self.class.path).to_hash
      end

      [
        HTTP::OK,
        MultiJson.dump(feature_flags, pretty: true)
      ]
    end

    get "#{path}/:name", :read
    def read(name)
      validate_access(:read, model)

      raise self.class.not_found_exception(name) unless FeatureFlag::DEFAULT_FLAGS.key?(name.to_sym)

      feature_flag = FeatureFlag.find(name: name)

      [
        HTTP::OK,
        FeatureFlagPresenter.new(feature_flag, name, self.class.path).to_json
      ]
    end

    put "#{path}/:name", :update_feature_flag
    def update_feature_flag(name)
      validate_access(:update, model)

      raise self.class.not_found_exception(name) unless FeatureFlag::DEFAULT_FLAGS.key?(name.to_sym)

      feature_flag_attributes = MultiJson.load(body)

      feature_flag = FeatureFlag.find(name: name)
      feature_flag ||= FeatureFlag.new(name: name)

      feature_flag.enabled = feature_flag_attributes['enabled']
      feature_flag.error_message = feature_flag_attributes['error_message']
      feature_flag.save

      [
        HTTP::OK,
        FeatureFlagPresenter.new(feature_flag, name, self.class.path).to_json
      ]
    end
  end
end
