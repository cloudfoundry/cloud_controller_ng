module VCAP::CloudController
  class ServiceBindingListFetcher
    def initialize(message)
      @message = message
    end

    def fetch(space_guids:)
      dataset = ServiceBinding.select_all(ServiceBinding.table_name).
                join(ServiceInstance, guid: :service_instance_guid).
                join(Space, id: :space_id, guid: space_guids)
      filter(dataset)
    end

    def fetch_all
      dataset = ServiceBinding.dataset
      filter(dataset)
    end

    private

    def filter(dataset)
      if @message.requested?(:app_guids)
        dataset = dataset.where(app_guid: @message.app_guids)
      end

      if @message.requested?(:service_instance_guids)
        dataset = dataset.where(service_instance_guid: @message.service_instance_guids)
      end

      dataset
    end
  end
end
