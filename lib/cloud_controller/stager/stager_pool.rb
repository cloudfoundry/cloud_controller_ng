require "cloud_controller/nats_messages/stager_advertisment"
require "cloud_controller/dea/eligible_dea_advertisement_filter"

module VCAP::CloudController
  class StagerPool
    attr_reader :config, :message_bus

    def initialize(config, message_bus)
      @config = config
      @message_bus = message_bus
      @stager_advertisements = []
    end

    def register_subscriptions
      message_bus.subscribe("staging.advertise") do |msg|
        process_advertise_message(msg)
      end
    end

    def process_advertise_message(msg)
      mutex.synchronize do
        advertisement = StagerAdvertisement.new(msg)
        remove_advertisement_for_id(advertisement.stager_id)
        @stager_advertisements << advertisement
      end
    end

    def logger
      @logger ||= Steno.logger("cc.stager.pool")
    end

    def find_stager(criteria)
      if logger.debug2?
        @stager_advertisements.each do |ad|
          logger.debug2 "#{ad.id} | #{ad.available_memory} | #{ad.available_disk} | #{ad.zone} | #{ad.stats["app_id_to_count"]}"
        end
      end

      mutex.synchronize do

        validate_stack_availability(criteria[:stack])
        prune_stale_advertisements

        criteria[:index] = 0
        clear_app_id_to_count_in_advertisement(criteria[:app_id])

        best_ad = EligibleDeaAdvertisementFilter.new(@stager_advertisements, criteria).
                       only_specific_zone.
                       only_with_disk.
                       only_meets_needs.
                       only_fewest_instances_of_app.
                       only_fewest_instances_of_all.
                       upper_by_memory.
                       sample

        logger.debug2 "best stager  = #{best_ad.id}" if best_ad

        best_ad && best_ad.id
      end
    end

    def validate_stack_availability(stack)
      unless @stager_advertisements.any? { |ad| ad.has_stack?(stack) }
        raise Errors::ApiError.new_from_details("StackNotFound", "The requested app stack #{stack} is not available on this system.")
      end
    end

    def reserve_app_memory(stager_id, app_memory)
      @stager_advertisements.find { |ad| ad.stager_id == stager_id }.decrement_memory(app_memory)
    end

    def reserve_app_disk(stager_id, app_disk_quota)
      @stager_advertisements.find { |ad| ad.stager_id == stager_id }.decrement_disk(app_disk_quota)
    end

    private
    def top_5_stagers_for(memory, disk, stack)
      @stager_advertisements.select do |advertisement|
        advertisement.meets_needs?(memory, stack) && advertisement.has_sufficient_disk?(disk)
      end.sort do |advertisement_a, advertisement_b|
        advertisement_a.available_memory <=> advertisement_b.available_memory
      end.last(5)
    end

    def prune_stale_advertisements
      @stager_advertisements.delete_if { |ad| ad.expired? }
    end

    def remove_advertisement_for_id(id)
      @stager_advertisements.delete_if { |ad| ad.stager_id == id }
    end

    def clear_app_id_to_count_in_advertisement(app_id)
      @stager_advertisements.each { |ad| ad.clear_app_id_to_count(app_id) }
    end

    def mutex
      @mutex ||= Mutex.new
    end
  end
end
