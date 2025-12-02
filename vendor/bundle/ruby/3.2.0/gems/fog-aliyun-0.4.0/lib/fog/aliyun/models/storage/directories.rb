# frozen_string_literal: true

require 'fog/core/collection'
require 'fog/aliyun/models/storage/directory'

module Fog
  module Aliyun
    class Storage
      class Directories < Fog::Collection
        model Fog::Aliyun::Storage::Directory

        def all
          buckets = service.get_service[0]
          return nil if buckets.size < 1
          data = []
          i = 0
          buckets.each do |b|
            data[i] = { key: b.name }
            i += 1
          end
          load(data)
        end


        def get(key, options = {})
          data = service.get_bucket(key, options)

          directory = new(:key => key, :is_persisted => true)

          options = data[1]
          options[:max_keys] = options[:limit]
          directory.files.merge_attributes(options)

          objects = []
          i = 0
          data[0].each do |o|
            objects[i] = {
                'Key' => o.key,
                'Type' => o.type,
                'Size' => o.size,
                'ETag' => o.etag,
                'LastModified' => o.last_modified
            }
            i += 1
          end
          directory.files.load(objects)
          directory
        rescue AliyunOssSdk::ServerError => error
          if error.error_code == "NoSuchBucket"
            nil
          else
            raise(error)
          end
        end
      end
    end
  end
end
