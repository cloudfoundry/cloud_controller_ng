require "cloud_controller/nats_messages/dea_advertisment"
require "cloud_controller/dea/eligible_dea_advertisement_filter"

module VCAP::CloudController
  class DeaPool
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

    def logger
      @logger ||= Steno.logger("cc.dea.pool")
    end

    def find_dea(criteria)
      if logger.debug2?
        @dea_advertisements.each do |ad|
          logger.debug2 "#{ad.id} | #{ad.available_memory} | #{ad.available_disk} | #{ad.zone} | #{ad.stats["app_id_to_count"]}"
        end
      end

      mutex.synchronize do
        prune_stale_deas

        best_ad = EligibleDeaAdvertisementFilter.new(@dea_advertisements, criteria).
                       only_valid_zone.
                       only_specific_zone.
                       only_with_disk.
                       only_meets_needs.
                       only_fewest_instances_of_app.
                       only_fewest_instances_of_all.
                       upper_by_memory.
                       sample

        logger.debug2 "best dea  = #{best_ad.id}" if best_ad

        best_ad && best_ad.id
      end
    end

    def mark_app_started(opts)
      dea_id = opts[:dea_id]
      app_id = opts[:app_id]

      @dea_advertisements.find { |ad| ad.dea_id == dea_id }.increment_instance_count(app_id)
    end

    def clear_app_id_to_count_in_advertisement(app_id)
      mutex.synchronize do
        @dea_advertisements.each { |ad| ad.clear_app_id_to_count(app_id) }
      end
    end

    def reserve_app_memory(dea_id, app_memory)
      @dea_advertisements.find { |ad| ad.dea_id == dea_id }.decrement_memory(app_memory)
    end

    def reserve_app_disk(dea_id, app_disk_quota)
      @dea_advertisements.find { |ad| ad.dea_id == dea_id }.decrement_disk(app_disk_quota)
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
  end
end
