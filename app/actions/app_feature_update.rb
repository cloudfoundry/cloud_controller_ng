module VCAP::CloudController
  class AppFeatureUpdate
    class InvalidCombination < StandardError; end

    class << self
      def update(feature_name, app, app_feature_update_message)
        app.update({ feature_column_name(feature_name) => app_feature_update_message.enabled })
      end

      def bulk_update(app, manifest_features_update_message)
        flags = {}

        manifest_features_update_message.features&.each do |feature_name, enabled|
          flags[feature_column_name(feature_name)] = enabled
        end

        return if flags.empty?

        check_invalid_combination!(app, flags)
        app.update(flags)
      end

      private

      def feature_column_name(feature_name)
        column = AppFeatures::DATABASE_COLUMNS_MAPPING[feature_name.to_s]
        raise "Unknown feature name: #{feature_name}" if column.nil?

        column
      end

      def check_invalid_combination!(app, flags)
        file_based_vcap_services_enabled = flags.fetch(feature_column_name(AppFeatures::FILE_BASED_VCAP_SERVICES_FEATURE), app.file_based_vcap_services_enabled)
        service_binding_k8s_enabled = flags.fetch(feature_column_name(AppFeatures::SERVICE_BINDING_K8S_FEATURE), app.service_binding_k8s_enabled)
        return unless file_based_vcap_services_enabled && service_binding_k8s_enabled

        msg = "'#{AppFeatures::FILE_BASED_VCAP_SERVICES_FEATURE}' and '#{AppFeatures::SERVICE_BINDING_K8S_FEATURE}' features cannot be enabled at the same time."
        raise InvalidCombination.new(msg)
      end
    end
  end
end
