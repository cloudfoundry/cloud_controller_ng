require 'cloud_controller/dea/nats_messages/dea_advertisment'
require 'cloud_controller/dea/eligible_advertisement_filter'

module VCAP::CloudController
  module Dea
    class Pool
      def initialize(config, message_bus)
        @advertise_timeout = config[:dea_advertisement_timeout_in_seconds]
        @message_bus = message_bus
        @percentage_of_top_stagers = (config[:placement_top_stager_percentage] || 0) / 100.0
        @dea_advertisements = {}
      end

      def register_subscriptions
        message_bus.subscribe('dea.advertise') do |msg|
          process_advertise_message(msg)
        end

        message_bus.subscribe('dea.shutdown') do |msg|
          process_shutdown_message(msg)
        end
      end

      def process_advertise_message(message)
        advertisement = NatsMessages::DeaAdvertisement.new(message, Time.now.utc.to_i + @advertise_timeout)

        mutex.synchronize do
          @dea_advertisements[advertisement.dea_id] = advertisement
        end
      end

      def process_shutdown_message(message)
        fake_advertisement = NatsMessages::DeaAdvertisement.new(message, Time.now.utc.to_i + @advertise_timeout)

        mutex.synchronize do
          @dea_advertisements.delete(fake_advertisement.dea_id)
        end
      end

      def find_dea(criteria)
        mutex.synchronize do
          prune_stale_deas

          best_dea_ad = EligibleAdvertisementFilter.new(@dea_advertisements, criteria[:app_id]).
                        only_with_disk(criteria[:disk] || 0).
                        only_meets_needs(criteria[:mem], criteria[:stack]).
                        only_in_zone_with_fewest_instances.
                        only_fewest_instances_of_app.
                        upper_half_by_memory.
                        sample

          best_dea_ad
        end
      end

      def find_stager(stack, memory, disk)
        mutex.synchronize do
          validate_stack_availability(stack)

          prune_stale_deas
          best_ad = top_n_stagers_for(memory, disk, stack).sample
          best_ad && best_ad[0]
        end
      end

      def mark_app_started(opts)
        dea_id = opts[:dea_id]
        app_id = opts[:app_id]

        @dea_advertisements[dea_id].increment_instance_count(app_id)
      end

      def reserve_app_memory(dea_id, app_memory)
        @dea_advertisements[dea_id].decrement_memory(app_memory)
      end

      private

      attr_reader :message_bus

      def prune_stale_deas
        now = Time.now.utc.to_i
        @dea_advertisements.delete_if { |_, ad| ad.expired?(now) }
      end

      def mutex
        @mutex ||= Mutex.new
      end

      def validate_stack_availability(stack)
        unless @dea_advertisements.any? { |_, ad| ad.has_stack?(stack) }
          raise Errors::ApiError.new_from_details('StackNotFound', "The requested app stack #{stack} is not available on this system.")
        end
      end

      def top_n_stagers_for(memory, disk, stack)
        @dea_advertisements.select { |id, ad|
          ad.meets_needs?(memory, stack) && ad.has_sufficient_disk?(disk)
        }.sort_by { |id, ad|
          ad.available_memory
        }.last([5, @percentage_of_top_stagers * @dea_advertisements.size].max.to_i)
      end
    end
  end
end
