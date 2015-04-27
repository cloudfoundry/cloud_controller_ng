module VCAP::CloudController
  class ProcessListFetcher
    def fetch_all(pagination_options)
      dataset = App.dataset
      paginate(dataset, pagination_options)
    end

    def fetch(pagination_options, space_guids)
      dataset = App.select_all(:apps).join(:spaces, id: :space_id, guid: space_guids)
      paginate(dataset, pagination_options)
    end

    private

    def paginate(dataset, pagination_options)
      dataset = dataset.eager(:space)
      SequelPaginator.new.get_page(dataset, pagination_options)
    end
  end
end
