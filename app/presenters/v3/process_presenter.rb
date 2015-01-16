require 'presenters/v3/pagination_presenter'

module VCAP::CloudController
  class ProcessPresenter
    def initialize(pagination_presenter=PaginationPresenter.new)
      @pagination_presenter = pagination_presenter
    end

    def present_json(process)
      MultiJson.dump(process_hash(process), pretty: true)
    end

    def present_json_list(paginated_result, base_url)
      processes      = paginated_result.records
      process_hashes = processes.collect { |app| process_hash(app) }

      paginated_response = {
        pagination: @pagination_presenter.present_pagination_hash(paginated_result, base_url),
        resources:  process_hashes
      }

      MultiJson.dump(paginated_response, pretty: true)
    end

    private

    def process_hash(process)
      {
        guid: process.guid,
        type: process.type,
      }
    end
  end
end
