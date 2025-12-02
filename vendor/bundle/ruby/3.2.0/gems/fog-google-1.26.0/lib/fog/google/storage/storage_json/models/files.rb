module Fog
  module Google
    class StorageJSON
      class Files < Fog::Collection
        model Fog::Google::StorageJSON::File

        extend Fog::Deprecation
        deprecate :get_url, :get_https_url

        attribute :common_prefixes, :aliases => "CommonPrefixes"
        attribute :delimiter,       :aliases => "Delimiter"
        attribute :directory
        attribute :page_token,      :aliases => %w(pageToken page_token)
        attribute :max_results,     :aliases => %w(MaxKeys max-keys)
        attribute :prefix,          :aliases => "Prefix"
        attribute :next_page_token

        def all(options = {})
          requires :directory
          parent = service.list_objects(directory.key, attributes.merge(options))
          attributes[:next_page_token] = parent.next_page_token
          data = parent.to_h[:items] || []
          load(data)
        end

        alias_method :each_file_this_page, :each
        def each(&block)
          if block_given?
            subset = dup.all

            subset.each_file_this_page(&block)
            while subset.next_page_token
              subset = subset.all(:page_token => subset.next_page_token)
              subset.each_file_this_page(&block)
            end
          end
          self
        end

        def get(key, options = {}, &block)
          requires :directory
          data = service.get_object(directory.key, key, **options, &block).to_h
          new(data)
        rescue ::Google::Apis::ClientError => e
          raise e unless e.status_code == 404

          nil
        end

        def get_https_url(key, expires, options = {})
          requires :directory
          service.get_object_https_url(directory.key, key, expires, **options)
        end

        def metadata(key, options = {})
          requires :directory
          data = service.get_object_metadata(directory.key, key, **options).to_h
          new(data)
        rescue ::Google::Apis::ClientError
          nil
        end
        alias_method :head, :metadata

        def new(opts = {})
          requires :directory
          super({ :directory => directory }.merge(opts))
        end
      end
    end
  end
end
