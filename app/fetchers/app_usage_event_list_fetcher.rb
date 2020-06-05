module VCAP::CloudController
  class AppUsageEventListFetcher
    class << self
      def fetch_all(message, dataset)
        if message.requested?(:after_guid)
          last_event = dataset.first(guid: message.after_guid[0])
          invalid_after_guid! unless last_event

          dataset = dataset.filter { id > last_event.id }
        end

        if message.requested?(:guids)
          dataset = dataset.where(guid: message.guids)
        end

        dataset
      end

      private

      def invalid_after_guid!
        raise CloudController::Errors::ApiError.new_from_details(
          'UnprocessableEntity',
          'After guid filter must be a valid app usage event guid.',
        )
      end
    end
  end
end
