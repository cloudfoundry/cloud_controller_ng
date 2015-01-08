require 'presenters/v3/pagination_presenter'

module VCAP::CloudController
  class AppPresenter
    def initialize(pagination_presenter=PaginationPresenter.new)
      @pagination_presenter = pagination_presenter
    end

    def present_json(app)
      MultiJson.dump(app_hash(app), pretty: true)
    end

    def present_json_list(paginated_result)
      apps       = paginated_result.records
      app_hashes = apps.collect { |app| app_hash(app) }

      paginated_response = {
        pagination: @pagination_presenter.present_pagination_hash(paginated_result, '/v3/apps'),
        resources:  app_hashes
      }

      MultiJson.dump(paginated_response, pretty: true)
    end

    private

    def app_hash(app)
      {
        guid:   app.guid,
        name:   app.name,

        _links: {
          self:      { href: "/v3/apps/#{app.guid}" },
          processes: { href: "/v3/apps/#{app.guid}/processes" },
          space:     { href: "/v2/spaces/#{app.space_guid}" },
        }
      }
    end
  end
end
