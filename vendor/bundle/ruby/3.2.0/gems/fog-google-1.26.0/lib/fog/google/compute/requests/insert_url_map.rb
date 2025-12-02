module Fog
  module Google
    class Compute
      class Mock
        def insert_url_map(_url_map_name, _url_map = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end

      class Real
        def insert_url_map(url_map_name, url_map = {})
          url_map[:host_rules] = url_map[:host_rules] || []
          url_map[:path_matchers] = url_map[:path_matchers] || []
          url_map[:tests] = url_map[:tests] || []

          url_map_obj = ::Google::Apis::ComputeV1::UrlMap.new(
            **url_map.merge(:name => url_map_name)
          )
          # HACK: Currently URL map insert may fail even though the backend
          # service operation is done. Retriable is not used to not add another
          # runtime dependency.
          # TODO: Remove after that has been corrected.
          begin
            retries ||= 0
            @compute.insert_url_map(@project, url_map_obj)
          rescue ::Google::Apis::ClientError
            Fog::Logger.warning("URL map insert failed, retrying...")
            sleep 10
            retry if (retries += 1) < 2
          end
        end
      end
    end
  end
end
