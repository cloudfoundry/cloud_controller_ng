require 'cloud_controller/dea/nats_messages/stager_advertisment'

module VCAP::CloudController
  module Dea
    class StagerPool
      attr_reader :config, :message_bus

      def initialize(config, message_bus, blobstore_url_generator)
        @advertise_timeout = config[:dea_advertisement_timeout_in_seconds]
        @message_bus = message_bus
        @stager_advertisements = []
        @blobstore_url_generator = blobstore_url_generator
        register_subscriptions
      end

      def process_advertise_message(msg)
        advertisement = NatsMessages::StagerAdvertisement.new(msg, Time.now.utc.to_i + @advertise_timeout)
        publish_buildpacks unless stager_in_pool?(advertisement.stager_id)

        mutex.synchronize do
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

      def reserve_app_memory(stager_id, app_memory)
        @stager_advertisements.find { |ad| ad.stager_id == stager_id }.decrement_memory(app_memory)
      end

      private

      def register_subscriptions
        message_bus.subscribe('staging.advertise') do |msg|
          process_advertise_message(msg)
        end
      end

      def publish_buildpacks
        message_bus.publish('buildpacks', admin_buildpacks)
      end

      def admin_buildpacks
        AdminBuildpacksPresenter.new(@blobstore_url_generator).to_staging_message_array
      end

      def validate_stack_availability(stack)
        unless @stager_advertisements.any? { |ad| ad.has_stack?(stack) }
          raise Errors::ApiError.new_from_details('StackNotFound', "The requested app stack #{stack} is not available on this system.")
        end
      end

      def top_5_stagers_for(memory, disk, stack)
        @stager_advertisements.select do |advertisement|
          advertisement.meets_needs?(memory, stack) && advertisement.has_sufficient_disk?(disk)
        end.sort do |advertisement_a, advertisement_b|
          advertisement_a.available_memory <=> advertisement_b.available_memory
        end.last(5)
      end

      def prune_stale_advertisements
        now = Time.now.utc.to_i
        @stager_advertisements.delete_if { |ad| ad.expired?(now) }
      end

      def stager_in_pool?(id)
        @stager_advertisements.map(&:stager_id).include? id
      end

      def remove_advertisement_for_id(id)
        @stager_advertisements.delete_if { |ad| ad.stager_id == id }
      end

      def mutex
        @mutex ||= Mutex.new
      end
    end
  end
end
