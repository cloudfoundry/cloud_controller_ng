module VCAP::CloudController
  class ServiceBindingListFetcher
    def initialize(message)
      @message = message
    end

    def fetch(space_guids:)
      dataset = ServiceBindingModel.select_all(:v3_service_bindings).
                join(:service_instances, id: :service_instance_id).
                join(:spaces, id: :space_id, guid: space_guids)
      filter(dataset)
    end

    def fetch_all
      dataset = ServiceBindingModel.dataset
      filter(dataset)
    end

    private

    def filter(dataset)
      if @message.requested?(:app_guids)
        dataset = dataset.join(:apps_v3, id: :v3_service_bindings__app_id, guid: @message.app_guids).select_all(:v3_service_bindings)
      end

      if @message.requested?(:service_instance_guids)
        service_instance_guids = @message.service_instance_guids
        dataset = join_service_instances_if_necessary(dataset, service_instance_guids)
        dataset = dataset.where(service_instances__guid: service_instance_guids)
      end

      dataset
    end

    def join_service_instances_if_necessary(dataset, service_instance_guids)
      return dataset if dataset.opts[:join] && dataset.opts[:join].any? { |j| j.table == :service_instances }
      dataset.join(:service_instances, id: :service_instance_id, guid: service_instance_guids).select_all(:v3_service_bindings)
    end
  end
end
