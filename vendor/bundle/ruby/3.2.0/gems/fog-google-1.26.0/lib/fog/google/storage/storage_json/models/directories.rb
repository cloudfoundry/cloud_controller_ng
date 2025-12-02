module Fog
  module Google
    class StorageJSON
      class Directories < Fog::Collection
        model Fog::Google::StorageJSON::Directory

        def all(opts = {})
          data = service.list_buckets(**opts).to_h[:items] || []
          load(data)
        end

        def get(bucket_name, options = {})
          if_metageneration_match = options[:if_metageneration_match]
          if_metageneration_not_match = options[:if_metageneration_not_match]
          projection = options[:projection]

          data = service.get_bucket(
            bucket_name,
            :if_metageneration_match => if_metageneration_match,
            :if_metageneration_not_match => if_metageneration_not_match,
            :projection => projection
          ).to_h

          directory = new(data)
          # Because fog-aws accepts these arguments on files at the
          # directories.get level, we need to preload the directory files
          # with these attributes here.
          files_attr_names = %i(delimiter page_token max_results prefix)

          file_opts = options.select { |k, _| files_attr_names.include? k }
          directory.files(file_opts)
          directory
        rescue ::Google::Apis::ClientError => e
          # metageneration check failures returns HTTP 412 Precondition Failed
          raise e unless e.status_code == 404 || e.status_code == 412

          nil
        end
      end
    end
  end
end
