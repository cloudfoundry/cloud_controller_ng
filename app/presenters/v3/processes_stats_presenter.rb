module VCAP::CloudController
  module Presenters
    module V3
      class ProcessesStatsPresenter < ProcessStatsPresenter
        def initialize(process_stats_pairs)
          @process_stats_pairs = process_stats_pairs
        end

        def to_hash
          {
            resources: @process_stats_pairs.flat_map do |process, stats|
              # Use the extended ProcessStatsPresenter logic for each process
              presenter = self.class.superclass.new(process.type, stats)
              presenter_hash = presenter.to_hash
              # Add process_guid to each instance stat
              presenter_hash[:resources].map do |instance_stat|
                instance_stat.merge(process_guid: process.guid)
              end
            end
          }
        end
      end
    end
  end
end
