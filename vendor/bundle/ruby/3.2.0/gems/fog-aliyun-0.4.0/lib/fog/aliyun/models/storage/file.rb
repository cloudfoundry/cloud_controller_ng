# frozen_string_literal: true

require 'fog/core/model'

module Fog
  module Aliyun
    class Storage
      class File < Fog::Model
        identity :key, aliases: ['Key', 'Name', 'name']

        attr_writer :body
        attribute :cache_control, aliases: 'Cache-Control'
        attribute :content_encoding, aliases: 'Content-Encoding'
        attribute :date, aliases: 'Date'
        attribute :content_length, aliases: ['Content-Length', 'Size'], type: :integer
        attribute :content_md5, aliases: 'Content-MD5'
        attribute :content_type, aliases: 'Content-Type'
        attribute :connection, aliases: 'Connection'
        attribute :content_disposition, aliases: 'Content-Disposition'
        attribute :etag, aliases: ['Etag', 'ETag']
        attribute :expires, aliases: 'Expires'
        attribute :metadata
        attribute :owner, aliases: 'Owner'
        attribute :last_modified, aliases: 'Last-Modified', type: :time
        attribute :accept_ranges, aliases: 'Accept-Ranges'
        attribute :server, aliases: 'Server'
        attribute :object_type, aliases: ['x-oss-object-type', 'x_oss_object_type']

        # @note Chunk size to use for multipart uploads.
        #     Use small chunk sizes to minimize memory. E.g. 5242880 = 5mb
        attr_reader :multipart_chunk_size
        def multipart_chunk_size=(mp_chunk_size)
          raise ArgumentError.new("minimum multipart_chunk_size is 5242880") if mp_chunk_size < 5242880
          @multipart_chunk_size = mp_chunk_size
        end

        def acl
          requires :directory, :key
          service.get_object_acl(directory.key, key)
        end

        def acl=(new_acl)
          valid_acls = ['private', 'public-read', 'public-read-write', 'default']
          unless valid_acls.include?(new_acl)
            raise ArgumentError.new("acl must be one of [#{valid_acls.join(', ')}]")
          end
          @acl = new_acl
        end

        def body
          return attributes[:body] if attributes[:body]
          return '' unless last_modified

          file = collection.get(identity)
          if file
            attributes[:body] = file.body
          else
            attributes[:body] = ''
          end
        end

        def body=(new_body)
          attributes[:body] = new_body
        end

        def directory
          @directory
        end

        # Copy object from one bucket to other bucket.
        #
        #     required attributes: directory, key
        #
        # @param target_directory_key [String]
        # @param target_file_key [String]
        # @param options [Hash] options for copy_object method
        # @return [String] Fog::Aliyun::Files#head status of directory contents
        #
        def copy(target_directory_key, target_file_key, options = {})
          requires :directory, :key
          service.copy_object(directory.key, key, target_directory_key, target_file_key, options)
          target_directory = service.directories.new(:key => target_directory_key)
          target_directory.files.head(target_file_key)
        end

        def destroy(options = {})
          requires :directory, :key
          # TODO support versionId
          # attributes[:body] = nil if options['versionId'] == version
          service.delete_object(directory.key, key, options)
          true
        end

        remove_method :metadata
        def metadata
          attributes.reject {|key, value| !(key.to_s =~ /^x-oss-/)}
        end

        remove_method :metadata=
        def metadata=(new_metadata)
          merge_attributes(new_metadata)
        end

        remove_method :owner=
        def owner=(new_owner)
          if new_owner
            attributes[:owner] = {
                :display_name => new_owner['DisplayName'] || new_owner[:display_name],
                :id           => new_owner['ID'] || new_owner[:id]
            }
          end
        end

        # Set Access-Control-List permissions.
        #
        #     valid new_publics: public_read, private
        #
        # @param [String] new_public
        # @return [String] new_public
        #
        def public=(new_public)
          if new_public
            @acl = 'public-read'
          else
            @acl = 'private'
          end
          new_public
        end

        # Get a url for file.
        #
        #     required attributes: directory, key
        #
        # @param expires [String] number of seconds (since 1970-01-01 00:00) before url expires
        # @param options[Hash] No need to use
        # @return [String] url
        #
        def url(expires, options = {})
          requires :key
          service.get_object_http_url_public(directory.key, key, expires)
        end

        def save(options = {})
          requires :body, :directory, :key
          options['x-oss-object-acl'] ||= @acl if @acl
          options['Cache-Control'] = cache_control if cache_control
          options['Content-Disposition'] = content_disposition if content_disposition
          options['Content-Encoding'] = content_encoding if content_encoding
          options['Content-MD5'] = content_md5 if content_md5
          options['Content-Type'] = content_type if content_type
          options['Expires'] = expires if expires
          options.merge!(metadata)

          self.multipart_chunk_size = 5242880 if !multipart_chunk_size && Fog::Storage.get_body_size(body) > 5368709120
          if multipart_chunk_size && Fog::Storage.get_body_size(body) >= multipart_chunk_size && body.respond_to?(:read)
            multipart_save(options)
          else
            service.put_object(directory.key, key, body, options)
          end
          self.etag = self.etag.gsub('"','') if self.etag
          self.content_length = Fog::Storage.get_body_size(body)
          self.content_type ||= Fog::Storage.get_content_type(body)
          true
        end

        private

        def directory=(new_directory)
          @directory = new_directory
        end

        def multipart_save(options)
          # Initiate the upload
          upload_id = service.initiate_multipart_upload(directory.key, key, options)

          # Store ETags of upload parts
          part_tags = []

          # Upload each part
          # TODO: optionally upload chunks in parallel using threads
          # (may cause network performance problems with many small chunks)
          # TODO: Support large chunk sizes without reading the chunk into memory
          if body.respond_to?(:rewind)
            body.rewind  rescue nil
          end
          while (chunk = body.read(multipart_chunk_size)) do
            part_upload = service.upload_part(directory.key, key, upload_id, part_tags.size + 1, chunk)
            part_tags << part_upload
          end

          if part_tags.empty? #it is an error to have a multipart upload with no parts
            part_upload = service.upload_part(directory.key, key, upload_id, 1, '')
            part_tags << part_upload
          end

        rescue
          # Abort the upload & reraise
          service.abort_multipart_upload(directory.key, key, upload_id) if upload_id
          raise
        else
          # Complete the upload
          service.complete_multipart_upload(directory.key, key, upload_id, part_tags)
        end

      end
    end
  end
end
