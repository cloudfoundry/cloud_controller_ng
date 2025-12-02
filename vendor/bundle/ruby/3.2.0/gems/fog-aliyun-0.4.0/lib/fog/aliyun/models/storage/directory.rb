# frozen_string_literal: true

require 'fog/core/model'
require 'fog/aliyun/models/storage/files'

module Fog
  module Aliyun
    class Storage
      class Directory < Fog::Model
        VALID_ACLS = ['private', 'public-read', 'public-read-write']

        attr_reader :acl
        identity :key, :aliases => ['Key', 'Name', 'name']

        attribute :creation_date, :aliases => 'CreationDate', :type => 'time'

        def acl=(new_acl)
          unless VALID_ACLS.include?(new_acl)
            raise ArgumentError.new("acl must be one of [#{VALID_ACLS.join(', ')}]")
          else
            @acl = new_acl
          end
        end

        def destroy
          requires :key
          service.delete_bucket(key)
          true
        rescue AliyunOssSdk::ServerError => error
          if error.error_code == "NoSuchBucket"
            false
          else
            raise(error)
          end
        end

        def destroy!(options = {})
          requires :key
          options = {
              timeout: Fog.timeout,
              interval: Fog.interval,
          }.merge(options)

          begin
            clear!
            Fog.wait_for(options[:timeout], options[:interval]) { objects_keys.size == 0 }
            service.delete_bucket(key)
            true
          rescue AliyunOssSdk::ServerError
            false
          end
        end

        def location
          region = @aliyun_region_id
          region ||= Storage::DEFAULT_REGION
          @location = (bucket_location || 'oss-' + region)
        end

        # NOTE: you can't change the region once the bucket is created
        def location=(new_location)
          new_location = 'oss-' + new_location unless new_location.start_with?('oss-')
          @location = new_location
        end

        def files
          @files ||= begin
            Fog::Aliyun::Storage::Files.new(
              directory: self,
              service: service
            )
          end
        end

        # TODO
        def public=(new_public)
          nil
        end

        # TODO
        def public_url
          nil
        end

        def save
          requires :key

          options = {}

          options['x-oss-acl'] = acl if acl

          # https://help.aliyun.com/document_detail/31959.html
          # if !persisted?
          #   # There is a sdk bug that location can not be set
          #   options[:location] = location
          # end

          service.put_bucket(key, options)
          attributes[:is_persisted] = true

          true
        end

        def persisted?
          # is_persisted is true in case of directories.get or after #save
          # creation_date is set in case of directories.all
          attributes[:is_persisted] || !!attributes[:creation_date]
        end

        private

        def bucket_location
          requires :key
          return nil unless persisted?
          service.get_bucket_location(key)
        end

        def objects_keys
          requires :key
          bucket_query = service.get_bucket(key)

          object_keys = []
          i = 0
          bucket_query[0].each do |o|
            object_keys[i] = o.key
            i += 1
          end
          object_keys
        end

        def clear!
          requires :key
          service.delete_multiple_objects(key, objects_keys) if objects_keys.size > 0
        end
      end
    end
  end
end
