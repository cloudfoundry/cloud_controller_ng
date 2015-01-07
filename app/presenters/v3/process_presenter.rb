module VCAP::CloudController
  class ProcessPresenter
    def present_json(process)
      MultiJson.dump(process_hash(process), pretty: true)
    end

    def present_json_list(paginated_result)
      processes     = paginated_result.records
      page          = paginated_result.page
      per_page      = paginated_result.per_page
      total_results = paginated_result.total

      process_hashes = processes.collect { |app| process_hash(app) }

      last_page     = (total_results.to_f / per_page.to_f).ceil
      last_page     = 1 if last_page < 1
      previous_page = page - 1
      next_page     = page + 1

      paginated_response = {
        pagination: {
          total_results: total_results,
          first:         { href: "/v3/processes?page=1&per_page=#{per_page}" },
          last:          { href: "/v3/processes?page=#{last_page}&per_page=#{per_page}" },
          next:          next_page <= last_page ? { href: "/v3/processes?page=#{next_page}&per_page=#{per_page}" } : nil,
          previous:      previous_page > 0 ? { href: "/v3/processes?page=#{previous_page}&per_page=#{per_page}" } : nil,
        },
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
