# frozen_string_literal: true

module Fog
  module Google
    class StorageJSON
      class Real
        # Create an object in an Google Storage bucket
        # https://cloud.google.com/storage/docs/json_api/v1/objects/insert
        #
        # @param bucket_name [String] Name of bucket to create object in
        # @param object_name [String] Name of object to create
        # @param data [File|String|Paperclip::AbstractAdapter] File, String or Paperclip adapter to create object from
        # @param options [Hash] Optional query parameters or Object attributes
        #   Optional query parameters are listed below.
        # @param content_encoding [String]
        #   If set, sets the contentEncoding property of the final object to
        #   this value.
        # @param if_generation_match [Fixnum]
        #   Makes the operation conditional on whether the object's current
        #   generation matches the given value. Setting to 0 makes the operation
        #   succeed only if there are no live versions of the object.
        # @param if_generation_not_match [Fixnum]
        #   Makes the operation conditional on whether the object's current
        #   generation does not match the given value. If no live object exists,
        #   the precondition fails. Setting to 0 makes the operation succeed
        #   only if there is a live version of the object.
        # @param if_metageneration_match [Fixnum]
        #   Makes the operation conditional on whether the object's
        #   current metageneration matches the given value.
        # @param if_metageneration_not_match [Fixnum]
        #   Makes the operation conditional on whether the object's
        #   current metageneration does not match the given value.
        # @param predefined_acl [String]
        #   Apply a predefined set of access controls to this object.
        # @param projection [String]
        #   Set of properties to return. Defaults to noAcl,
        #   unless the object resource specifies the acl property,
        #   when it defaults to full.
        # @return [Google::Apis::StorageV1::Object]
        def put_object(bucket_name,
                       object_name,
                       data,
                       content_encoding: nil,
                       if_generation_match: nil,
                       if_generation_not_match: nil,
                       if_metageneration_match: nil,
                       if_metageneration_not_match: nil,
                       kms_key_name: nil,
                       predefined_acl: nil,
                       **options)
          data, options = normalize_data(data, options)

          object_config = ::Google::Apis::StorageV1::Object.new(
            **options.merge(:name => object_name)
          )

          @storage_json.insert_object(
            bucket_name, object_config,
            :content_encoding => content_encoding,
            :if_generation_match => if_generation_match,
            :if_generation_not_match => if_generation_not_match,
            :if_metageneration_match => if_metageneration_match,
            :if_metageneration_not_match => if_metageneration_not_match,
            :kms_key_name => kms_key_name,
            :predefined_acl => predefined_acl,
            :options => ::Google::Apis::RequestOptions.default.merge(options),
            # see https://developers.google.com/api-client-library/ruby/guide/media_upload
            :content_type => options[:content_type],
            :upload_source => data
          )
        end

        protected

        def normalize_data(data, options)
          raise ArgumentError.new("data is required") unless data
          if data.is_a?(String)
            data = StringIO.new(data)
            options[:content_type] ||= "text/plain"
          elsif data.is_a?(::File)
            options[:content_type] ||= Fog::Storage.parse_data(data)[:headers]["Content-Type"]
          end

          # Paperclip::AbstractAdapter
          if data.respond_to?(:content_type) && data.respond_to?(:path)
            options[:content_type] ||= data.content_type
            data = data.path
          end
          [data, options]
        end
      end

      class Mock
        def put_object(_bucket_name, _object_name, _data, _options = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
