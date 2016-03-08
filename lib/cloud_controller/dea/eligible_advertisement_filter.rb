module VCAP::CloudController
  module Dea
    class EligibleAdvertisementFilter
      def initialize(dea_advertisements, app_id)
        @filtered_advertisements = dea_advertisements.values
        @app_id = app_id

        @instance_counts_by_zones = Hash.new(0)
        @filtered_advertisements.each { |ad| @instance_counts_by_zones[ad.zone] += ad.num_instances_of(@app_id) }
      end

      def only_with_disk(minimum_disk)
        @filtered_advertisements.select! { |ad| ad.has_sufficient_disk?(minimum_disk) }
        self
      end

      def only_meets_needs(mem, stack)
        @filtered_advertisements.select! { |ad| ad.meets_needs?(mem, stack) }
        self
      end

      def only_fewest_instances_of_app
        fewest_instances_of_app = @filtered_advertisements.map { |ad| ad.num_instances_of(@app_id) }.min
        @filtered_advertisements.select! { |ad| ad.num_instances_of(@app_id) == fewest_instances_of_app }
        self
      end

      def upper_half_by_memory
        unless @filtered_advertisements.empty?
          @filtered_advertisements.sort_by!(&:available_memory)
          min_eligible_memory = @filtered_advertisements[@filtered_advertisements.size / 2].available_memory
          @filtered_advertisements.select! { |ad| ad.available_memory >= min_eligible_memory }
        end

        self
      end

      def sample
        @filtered_advertisements.sample
      end

      def only_in_zone_with_fewest_instances
        minimum_instance_count = @filtered_advertisements.map { |ad| @instance_counts_by_zones[ad.zone] }.min
        @filtered_advertisements.select! { |ad| @instance_counts_by_zones[ad.zone] == minimum_instance_count }
        self
      end
    end
  end
end
