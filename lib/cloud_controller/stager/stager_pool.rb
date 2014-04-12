require "cloud_controller/nats_messages/stager_advertisment"

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

    def find_stager(stack, memory, disk)
      mutex.synchronize do
        validate_stack_availability(stack)

        prune_stale_advertisements
        best_ad = top_5_stagers_for(memory, disk, stack).sample
        best_ad && best_ad.stager_id
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

    def mutex
      @mutex ||= Mutex.new
    end
  end
end
