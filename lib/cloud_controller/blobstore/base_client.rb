require 'find'
require 'cloud_controller/blobstore/blob'
require 'cloud_controller/blobstore/blob_key_generator'

module CloudController
  module Blobstore
    class BaseClient
      def cp_r_to_blobstore(source_dir)
        digest_duration = 0
        exists_duration = 0
        upload_duration = 0
        digest_count = 0
        exists_count = 0
        upload_count = 0
        upload_attempts = 0
        traversal_completed = false

        begin
          unless File.directory?(source_dir)
            logger.error('blobstore.cp_r.source_dir_missing', source_dir: source_dir)
            raise Errno::ENOENT.new(source_dir)
          end

          Find.find(source_dir).each do |path|
            begin
              stat = File.stat(path)
            rescue SystemCallError
              next
            end
            next unless stat.file?
            next unless within_limits?(stat.size)
            next unless stat.mode.to_s(8)[3..5].to_i(8) >= 0o600

            t = Time.now.utc
            begin
              digest_count += 1
              sha1 = Digester.new.digest_path(path)
            ensure
              digest_duration += Time.now.utc - t
            end

            t = Time.now.utc
            begin
              exists_count += 1
              exists = exists?(sha1)
            ensure
              exists_duration += Time.now.utc - t
            end

            next if exists

            t = Time.now.utc
            upload_attempts += 1
            begin
              cp_to_blobstore(path, sha1)
              upload_count += 1
            ensure
              upload_duration += Time.now.utc - t
            end
          end
          traversal_completed = true
        ensure
          logger.info('blobstore.cp_r.digest', duration_seconds: digest_duration, count: digest_count, completed: traversal_completed)
          logger.info('blobstore.cp_r.exists', duration_seconds: exists_duration, count: exists_count, completed: traversal_completed)
          logger.info('blobstore.cp_r.upload', duration_seconds: upload_duration, count: upload_count, attempted: upload_attempts, completed: traversal_completed)
        end
      end

      def cp_to_blobstore(_, _)
        raise NotImplementedError
      end

      private

      def logger
        @logger ||= Steno.logger('cc.blobstore')
      end

      def partitioned_key(key)
        key             = key.to_s.downcase
        partitioned_key = BlobKeyGenerator.full_path_from_key(key)
        partitioned_key = File.join(@root_dir, partitioned_key) if @root_dir
        partitioned_key
      end

      def within_limits?(size)
        size >= @min_size && (@max_size.nil? || size <= @max_size)
      end
    end
  end
end
