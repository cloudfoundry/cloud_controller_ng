module VCAP::CloudController
  module Presenters
    module V3
      class ProcessesStatePresenter < ProcessStatsPresenter
        def initialize(type, process_stats, process_guid, app_guid)
          super(type, process_stats)
          @process_guid = process_guid
          @app_guid = app_guid
        end

        private

        def found_instance_stats_hash(index, stats)
          super.tap do |presented_stats|
            presented_stats.delete(:mem_quota)
            presented_stats.delete(:disk_quota)
            presented_stats.delete(:log_rate_limit)
            presented_stats.delete(:usage)

            presented_stats[:process_guid] = @process_guid
            presented_stats[:app_guid] = @app_guid
          end
        end

        def down_instance_stats_hash(index, stats)
          super.tap do |presented_stats|
            presented_stats[:process_guid] = @process_guid
            presented_stats[:app_guid] = @app_guid
          end
        end
      end
    end
  end
end
