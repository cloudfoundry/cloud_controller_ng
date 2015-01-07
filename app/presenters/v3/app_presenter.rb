module VCAP::CloudController
  class AppPresenter
    def present_json(app)
      MultiJson.dump(app_hash(app), pretty: true)
    end

    def present_json_list(paginated_result)
      apps          = paginated_result.records
      page          = paginated_result.page
      per_page      = paginated_result.per_page
      total_results = paginated_result.total

      app_hashes = apps.collect { |app| app_hash(app) }

      last_page     = (total_results.to_f / per_page.to_f).ceil
      last_page     = 1 if last_page < 1
      previous_page = page - 1
      next_page     = page + 1

      paginated_response = {
        pagination: {
          total_results: total_results,
          first_url:     "/v3/apps?page=1&per_page=#{per_page}",
          last_url:      "/v3/apps?page=#{last_page}&per_page=#{per_page}",
          previous_url:  previous_page > 0 ? "/v3/apps?page=#{previous_page}&per_page=#{per_page}" : nil,
          next_url:      next_page <= last_page ? "/v3/apps?page=#{next_page}&per_page=#{per_page}" : nil,
        },
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
