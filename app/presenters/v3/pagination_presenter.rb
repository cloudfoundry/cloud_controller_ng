module VCAP::CloudController
  class PaginationPresenter
    class DataToQueryParamsSerializer
      def serialize(facets)
        facet_to_query(facets)
      end

      private

      def facet_to_query(facet, namespace=nil)
        if facet.is_a? Hash
          hash_to_query(facet, namespace)
        elsif facet.is_a? Array
          array_to_query(facet, namespace)
        else
          "#{namespace}=#{facet}"
        end
      end

      def hash_to_query(hash, namespace=nil)
        hash.collect do |key, value|
          facet_to_query(value, namespace ? "#{namespace}[#{key}]" : key)
        end.sort * '&'
      end

      def array_to_query(array, key)
        prefix = "#{key}[]"

        if array.empty?
          ''
        else
          array.collect { |value| facet_to_query(value, prefix) }.join '&'
        end
      end
    end

    def present_pagination_hash(paginated_result, base_url, facets={})
      page          = paginated_result.pagination_options.page
      per_page      = paginated_result.pagination_options.per_page
      total_results = paginated_result.total

      last_page     = (total_results.to_f / per_page.to_f).ceil
      last_page     = 1 if last_page < 1
      previous_page = page - 1
      next_page     = page + 1
      serialized_facets = DataToQueryParamsSerializer.new.serialize(facets)
      serialized_facets += '&' if !serialized_facets.empty?

      {
        total_results: total_results,
        first:         { href: "#{base_url}?#{serialized_facets}page=1&per_page=#{per_page}" },
        last:          { href: "#{base_url}?#{serialized_facets}page=#{last_page}&per_page=#{per_page}" },
        next:          next_page <= last_page ? { href: "#{base_url}?#{serialized_facets}page=#{next_page}&per_page=#{per_page}" } : nil,
        previous:      previous_page > 0 ? { href: "#{base_url}?#{serialized_facets}page=#{previous_page}&per_page=#{per_page}" } : nil,
      }
    end
  end
end
