module VCAP::CloudController
  class ServiceBindingListFetcher
    def fetch(message:, space_guids:)
      pagination_options = message.pagination_options
      dataset = ServiceBindingModel.select_all(:v3_service_bindings).
                join(:service_instances, id: :service_instance_id).
                join(:spaces, id: :space_id, guid: space_guids)
      paginate(dataset, pagination_options)
    end

    def fetch_all(message:)
      pagination_options = message.pagination_options
      dataset = ServiceBindingModel.dataset
      paginate(dataset, pagination_options)
    end

    private

    def paginate(dataset, pagination_options)
      SequelPaginator.new.get_page(dataset, pagination_options)
    end
  end
end
