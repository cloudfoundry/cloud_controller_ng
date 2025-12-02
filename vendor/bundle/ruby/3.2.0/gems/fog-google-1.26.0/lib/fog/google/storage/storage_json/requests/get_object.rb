require "tempfile"

module Fog
  module Google
    class StorageJSON
      class Real
        # Get an object from Google Storage
        # @see https://cloud.google.com/storage/docs/json_api/v1/objects/get
        #
        # @param bucket_name [String] Name of bucket to create object in
        # @param object_name [String] Name of object to create
        # @param generation [Fixnum]
        #   If present, selects a specific revision of this object (as opposed to the latest version, the default).
        # @param ifGenerationMatch [Fixnum]
        #   Makes the operation conditional on whether the object's current generation matches the given value. Setting to 0 makes the operation succeed only if there are no live versions of the object.
        # @param ifGenerationNotMatch [Fixnum]
        #   Makes the operation conditional on whether the object's current generation does not match the given value. If no live object exists, the precondition fails. Setting to 0 makes the operation succeed only if there is a live version of the object.
        # @param ifMetagenerationMatch [Fixnum]
        #   Makes the operation conditional on whether the object's current metageneration matches the given value.
        # @param ifMetagenerationNotMatch [Fixnum]
        #   Makes the operation conditional on whether the object's current metageneration does not match the given value.
        # @param projection [Fixnum]
        #   Set of properties to return
        # @param options [Hash]
        #   Request-specific options
        # @param &block [Proc]
        #   Block to pass a streamed object response to. Expected format is
        #   same as Excon :response_block ({ |chunk, remaining_bytes, total_bytes| ... })
        # @return [Hash] Object metadata with :body attribute set to contents of object
        def get_object(bucket_name, object_name,
                       generation: nil,
                       if_generation_match: nil,
                       if_generation_not_match: nil,
                       if_metageneration_match: nil,
                       if_metageneration_not_match: nil,
                       projection: nil,
                       **options, &_block)
          raise ArgumentError.new("bucket_name is required") unless bucket_name
          raise ArgumentError.new("object_name is required") unless object_name

          buf = Tempfile.new("fog-google-storage-temp")
          buf.binmode
          buf.unlink

          # Two requests are necessary, first for metadata, then for content.
          # google-api-ruby-client doesn't allow fetching both metadata and content
          request_options = ::Google::Apis::RequestOptions.default.merge(options)
          all_opts = {
            :generation => generation,
            :if_generation_match => if_generation_match,
            :if_generation_not_match => if_generation_not_match,
            :if_metageneration_match => if_metageneration_match,
            :if_metageneration_not_match => if_metageneration_not_match,
            :projection => projection,
            :options => request_options
          }

          object = @storage_json.get_object(bucket_name, object_name, **all_opts).to_h
          @storage_json.get_object(
            bucket_name,
            object_name,
            **all_opts.merge(:download_dest => buf)
          )

          buf.seek(0)

          if block_given?
            yield buf.read, nil, nil
          else
            object[:body] = buf.read
          end

          object
        ensure
          buf.close! rescue nil
        end
      end

      class Mock
        def get_object(_bucket_name, _object_name, _options = {})
          # :no-coverage:
          Fog::Mock.not_implemented
          # :no-coverage:
        end
      end
    end
  end
end
