require 'cloud_controller/paging/sequel_paginator'
require 'cloud_controller/paging/paginated_result'
require 'fetchers/label_selector_query_generator'
require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class FeatureFlagListFetcher < BaseListFetcher
    class << self
      def fetch_all(message, eager_loaded_associations: [])
        db_feature_flags = FeatureFlag.dataset
        if message.updated_ats
          db_feature_flags = filter(message, db_feature_flags).all
        else
          FeatureFlag::DEFAULT_FLAGS.collect do |feature_flag_name, default_enabled_state|
            db_flag = db_feature_flags.find { |feature_flag| feature_flag.name == feature_flag_name.to_s }
            db_flag || FeatureFlag.new(name: feature_flag_name, enabled: default_enabled_state)
          end
        end
      end

      private

      def filter(message, dataset)
        super(message, dataset, FeatureFlag)
      end
    end
  end
end
