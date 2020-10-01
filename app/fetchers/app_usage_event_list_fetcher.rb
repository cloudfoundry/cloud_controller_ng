require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class AppUsageEventListFetcher < BaseListFetcher
    class << self
      def fetch_all(message, dataset)
        filter(message, dataset)
      end

      private

      def filter(message, dataset)
        if message.requested?(:after_guid)
          last_event = dataset.first(guid: message.after_guid[0])
          invalid_after_guid! unless last_event

          dataset = dataset.filter { id > last_event.id }
        end

        super(message, dataset, AppUsageEvent)
      end

      def invalid_after_guid!
        raise CloudController::Errors::ApiError.new_from_details(
          'UnprocessableEntity',
          'After guid filter must be a valid app usage event guid.',
        )
      end
    end
  end
end
