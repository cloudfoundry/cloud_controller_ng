require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class ServiceBindingListFetcher < BaseListFetcher
    class << self
      def fetch(message:, space_guids:)
        dataset = ServiceBinding.select_all(ServiceBinding.table_name).
                  join(ServiceInstance.table_name, guid: :service_instance_guid).
                  join(Space.table_name, id: :space_id, guid: space_guids)
        filter(dataset, message)
      end

      def fetch_all(message:)
        dataset = ServiceBinding.dataset
        filter(dataset, message)
      end

      def fetch_service_instance_bindings_in_space(service_instance_guid, space_guid)
        ServiceBinding.select_all(ServiceBinding.table_name).
          join(:apps, guid: :app_guid).
          where(apps__space_guid: space_guid).
          where(service_bindings__service_instance_guid: service_instance_guid)
      end

      private

      def filter(dataset, message)
        if message.requested?(:app_guids)
          dataset = dataset.where(app_guid: message.app_guids)
        end

        if message.requested?(:service_instance_guids)
          dataset = dataset.where(service_instance_guid: message.service_instance_guids)
        end

        super(message, dataset, ServiceBinding)
      end
    end
  end
end
