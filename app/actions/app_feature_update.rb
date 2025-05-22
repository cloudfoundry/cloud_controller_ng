module VCAP::CloudController
  class AppFeatureUpdate
    class InvalidCombination < StandardError; end

    class << self
      def update(feature_name, app, app_feature_update_message)
        app.update({ database_column(feature_name) => app_feature_update_message.enabled })
      end

      def bulk_update(app, manifest_features_update_message)
        flags = {}

        manifest_features_update_message.features&.each do |feature_name, enabled|
          flags[database_column(feature_name)] = enabled
        end

        app.update(flags) unless flags.empty?
      rescue Sequel::DatabaseError => e # Sequel::CheckConstraintViolation error only works for PostgreSQL
        raise e unless e.message.include?('only_one_sb_feature_enabled')

        msg = "'#{AppFeatures::FILE_BASED_VCAP_SERVICES_FEATURE}' and '#{AppFeatures::SERVICE_BINDING_K8S_FEATURE}' features cannot be enabled at the same time."
        raise InvalidCombination.new(msg)
      end

      private

      def database_column(feature_name)
        column = AppFeatures::DATABASE_COLUMNS_MAPPING[feature_name.to_s]
        raise "Unknown feature name: #{feature_name}" if column.nil?

        column
      end
    end
  end
end
