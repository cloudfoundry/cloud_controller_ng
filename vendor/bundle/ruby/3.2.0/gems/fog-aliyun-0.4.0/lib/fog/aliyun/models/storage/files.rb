# frozen_string_literal: true

require 'fog/core/collection'
require 'fog/aliyun/models/storage/file'
require 'aliyun/oss'

module Fog
  module Aliyun
    class Storage
      class Files < Fog::Collection
        attribute :directory
        attribute :limit
        attribute :prefix,          :aliases => 'Prefix'
        attribute :path
        attribute :common_prefixes, :aliases => 'CommonPrefixes'
        attribute :delimiter,       :aliases => 'Delimiter'
        attribute :is_truncated,    :aliases => 'IsTruncated'
        attribute :marker,          :aliases => 'Marker'
        attribute :max_keys,        :aliases => ['MaxKeys', 'max-keys']

        model Fog::Aliyun::Storage::File

        def all(options = {})
          requires :directory
          options = {
              'delimiter': delimiter,
              'marker': marker,
              'max-keys': max_keys.to_i,
              'prefix': prefix
          }.merge!(options)
          options = options.reject {|key,value| value.nil? || value.to_s.empty?}
          merge_attributes(options)
          parent = directory.collection.get(
              directory.key,
              options
          )
          if parent
            merge_attributes(parent.files.attributes)
            load(parent.files.map {|file| file.attributes})
          else
            nil
          end
        end

        alias_method :each_file_this_page, :each

        def each
          if !block_given?
            self
          else
            subset = dup.all

            subset.each_file_this_page { |f| yield f }
            while subset.is_truncated
              subset = subset.all(marker: subset.last.key)
              subset.each_file_this_page { |f| yield f }
            end

            self
          end
        end

        def get(key, options = {}, &block)
          requires :directory
          begin
            data = service.get_object(directory.key, key, options, &block)
            normalize_headers(data)
            file_data = data.headers.merge({
                                               :body => data.body,
                                               :key  => key
                                           })
            new(file_data)
          rescue Exception => error
            if error.respond_to?(:http_code) && error.http_code.to_i == 404
              nil
            else
              raise(error)
            end
          end
        end

        # @param options[Hash] No need to use
        def get_url(key, options = {})
          requires :directory
          service.get_object_http_url_public(directory.key, key, 3600)
        end

        # @param options[Hash] No need to use
        def get_http_url(key, expires, options = {})
          requires :directory
          service.get_object_http_url_public(directory.key, key, expires)
        end

        # @param options[Hash] No need to use
        def get_https_url(key, expires, options = {})
          requires :directory
          service.get_object_https_url_public(directory.key, key, expires)
        end

        def head(key, options = {})
          requires :directory
          begin
            data = service.head_object(directory.key, key, options)
            normalize_headers(data)
            file_data = data.headers.merge({
                                               :key => key
                                           })
            new(file_data)
          rescue Exception => error
            if error.respond_to?(:http_code) && error.http_code.to_i == 404
              nil
            else
              raise(error)
            end
          end
        end

        def new(attributes = {})
          requires :directory
          super({ :directory => directory }.merge!(attributes))
        end

        def normalize_headers(data)
          data.headers[:last_modified] = Time.parse(data.headers[:last_modified])
          data.headers[:etag] = data.headers[:etag].gsub('"','')
        end
      end
    end
  end
end
