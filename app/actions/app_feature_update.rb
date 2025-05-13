module VCAP::CloudController
  class AppFeatureUpdate
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
