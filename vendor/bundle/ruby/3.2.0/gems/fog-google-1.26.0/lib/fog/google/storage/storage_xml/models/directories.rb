module Fog
  module Google
    class StorageXML
      class Directories < Fog::Collection
        model Fog::Google::StorageXML::Directory

        def all
          data = service.get_service.body["Buckets"]
          load(data)
        end

        def get(key, options = {})
          remap_attributes(options,             :delimiter => "delimiter",
                                                :marker => "marker",
                                                :max_keys => "max-keys",
                                                :prefix => "prefix")
          data = service.get_bucket(key, options).body
          directory = new(:key => data["Name"])
          options = {}
          data.each_pair do |k, v|
            if %w(CommonPrefixes Delimiter IsTruncated Marker MaxKeys Prefix).include?(k)
              options[k] = v
            end
          end
          directory.files.merge_attributes(options)
          directory.files.load(data["Contents"])
          directory
        rescue Excon::Errors::NotFound
          nil
        end
      end
    end
  end
end
