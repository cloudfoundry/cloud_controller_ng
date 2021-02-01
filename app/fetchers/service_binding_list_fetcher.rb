require 'fetchers/base_list_fetcher'

module VCAP::CloudController
  class ServiceBindingListFetcher < BaseListFetcher
    class << self
      def fetch_service_instance_bindings_in_space(service_instance_guid, space_guid)
        ServiceBinding.select_all(ServiceBinding.table_name).
          join(:apps, guid: :app_guid).
          where(apps__space_guid: space_guid).
          where(service_bindings__service_instance_guid: service_instance_guid)
      end
    end
  end
end
