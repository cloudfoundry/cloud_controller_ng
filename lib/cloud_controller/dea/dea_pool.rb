# Copyright (c) 2009-2012 VMware, Inc.

require "vcap/stager/client"

module VCAP::CloudController
  class DeaPool
    ADVERTISEMENT_EXPIRATION = 10

    def initialize(message_bus)
      @message_bus = message_bus
      @dea_advertisements = []
    end

    def register_subscriptions
      message_bus.subscribe("dea.advertise") do |msg|
        process_advertise_message(msg)
      end

      message_bus.subscribe("dea.shutdown") do |msg|
        process_shutdown_message(msg)
      end
    end

    def process_advertise_message(message)
      mutex.synchronize do
        advertisement = DeaAdvertisement.new(message)

        remove_advertisement_for_id(advertisement.dea_id)
        @dea_advertisements << advertisement
      end
    end

    def process_shutdown_message(message)
      fake_advertisement = DeaAdvertisement.new(message)

      mutex.synchronize do
        remove_advertisement_for_id(fake_advertisement.dea_id)
      end
    end

    def find_dea(mem, stack, app_id)
      mutex.synchronize do
        prune_stale_deas

        best_dea_ad = EligibleDeaAdvertisementFilter.new(@dea_advertisements).
                       only_meets_needs(mem, stack).
                       only_fewest_instances_of_app(app_id).
                       upper_half_by_memory.
                       sample

        best_dea_ad && best_dea_ad.dea_id
      end
    end

    def mark_app_started(opts)
      dea_id = opts[:dea_id]
      app_id = opts[:app_id]

      @dea_advertisements.find { |ad| ad.dea_id == dea_id }.increment_instance_count(app_id)
    end

    private

    attr_reader :message_bus

    def prune_stale_deas
      @dea_advertisements.delete_if { |ad| ad.expired? }
    end

    def remove_advertisement_for_id(id)
      @dea_advertisements.delete_if { |ad| ad.dea_id == id }
    end

    def mutex
      @mutex ||= Mutex.new
    end

    class DeaAdvertisement
      attr_reader :stats

      def initialize(stats)
        @stats = stats
        @updated_at = Time.now
      end

      def increment_instance_count(app_id)
        stats[:app_id_to_count][app_id.to_sym] = num_instances_of(app_id.to_sym) + 1
      end

      def num_instances_of(app_id)
        stats[:app_id_to_count].fetch(app_id.to_sym, 0)
      end

      def available_memory
        stats[:available_memory]
      end

      def dea_id
        stats[:id]
      end

      def expired?
        (Time.now.to_i - @updated_at.to_i) > ADVERTISEMENT_EXPIRATION
      end

      def meets_needs?(mem, stack)
        has_sufficient_memory?(mem) && has_stack?(stack)
      end

      def has_stack?(stack)
        stats[:stacks].include?(stack)
      end

      def has_sufficient_memory?(mem)
        available_memory >= mem
      end
    end

    class EligibleDeaAdvertisementFilter
      def initialize(dea_advertisements)
        @dea_advertisements = dea_advertisements.dup
      end

      def only_meets_needs(mem, stack)
        @dea_advertisements.select! { |ad| ad.meets_needs?(mem, stack) }
        self
      end

      def only_fewest_instances_of_app(app_id)
        fewest_instances_of_app = @dea_advertisements.map { |ad| ad.num_instances_of(app_id) }.min
        @dea_advertisements.select! { |ad| ad.num_instances_of(app_id) == fewest_instances_of_app }
        self
      end

      def upper_half_by_memory
        unless @dea_advertisements.empty?
          @dea_advertisements.sort_by! { |ad| ad.available_memory }
          min_eligible_memory = @dea_advertisements[@dea_advertisements.size/2].available_memory
          @dea_advertisements.select! { |ad| ad.available_memory >= min_eligible_memory }
        end

        self
      end

      def sample
        @dea_advertisements.sample
      end
    end
  end
end
