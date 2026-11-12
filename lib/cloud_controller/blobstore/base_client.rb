require 'cloud_controller/blobstore/blob'
require 'cloud_controller/blobstore/blob_key_generator'

module CloudController
  module Blobstore
    class BaseClient
      def cp_r_to_blobstore(source_dir)
        counters = new_cp_r_counters
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

            cp_r_digest_file(path, counters)
            sha1 = counters[:last_sha1]

            next unless sha1

            exists = cp_r_check_exists(sha1, counters)
            next if exists.nil? # exists? raised, already logged
            next if exists

            cp_r_upload_file(path, sha1, counters)
          end
          traversal_completed = true
        ensure
          log_cp_r_phases(counters, traversal_completed)
        end
      end

      def cp_to_blobstore(_, _)
        raise NotImplementedError
      end

      private

      def new_cp_r_counters
        { digest_duration: 0, exists_duration: 0, upload_duration: 0,
          digest_count: 0, exists_count: 0, upload_count: 0,
          upload_attempts: 0, exists_errors: 0, last_sha1: nil }
      end

      def cp_r_digest_file(path, counters)
        t = Time.now.utc
        counters[:digest_count] += 1
        counters[:last_sha1] = Digester.new.digest_path(path)
      ensure
        counters[:digest_duration] += Time.now.utc - t
      end

      def cp_r_check_exists(sha1, counters)
        t = Time.now.utc
        counters[:exists_count] += 1
        exists?(sha1)
      rescue StandardError => e
        counters[:exists_errors] += 1
        logger.error('blobstore.cp_r.exists.error', sha1: sha1, error: e.message)
        nil
      ensure
        counters[:exists_duration] += Time.now.utc - t
      end

      def cp_r_upload_file(path, sha1, counters)
        t = Time.now.utc
        counters[:upload_attempts] += 1
        cp_to_blobstore(path, sha1)
        counters[:upload_count] += 1
      ensure
        counters[:upload_duration] += Time.now.utc - t
      end

      def log_cp_r_phases(ctrs, completed)
        logger.info('blobstore.cp_r.digest',
                    files_scanned: ctrs[:digest_count],
                    duration_seconds: ctrs[:digest_duration],
                    completed: completed)
        log_exists_phase(ctrs, completed)
        ua = ctrs[:upload_attempts]
        logger.info('blobstore.cp_r.upload',
                    files_to_upload: ua,
                    files_uploaded: ctrs[:upload_count],
                    files_failed: ua - ctrs[:upload_count],
                    duration_seconds: ctrs[:upload_duration],
                    completed: completed)
      end

      def log_exists_phase(ctrs, completed)
        checks   = ctrs[:exists_count]
        attempts = ctrs[:upload_attempts]
        errors   = ctrs[:exists_errors]
        hits     = checks - attempts - errors
        resolved = checks - errors # checks that did not error

        logger.info('blobstore.cp_r.exists',
                    files_checked: checks,
                    duration_seconds: ctrs[:exists_duration],
                    avg_duration_seconds: safe_div(ctrs[:exists_duration], checks),
                    cache_hits: hits,
                    cache_misses: attempts,
                    cache_hit_rate: safe_div(hits, resolved),
                    process_spawns: checks,
                    error_count: errors,
                    completed: completed)
      end

      def safe_div(num, denom) = denom.positive? ? num.to_f / denom : 0

      def partitioned_key(key)
        key             = key.to_s.downcase
        partitioned_key = BlobKeyGenerator.full_path_from_key(key)
        partitioned_key = File.join(@root_dir, partitioned_key) if @root_dir
        partitioned_key
      end

      def within_limits?(size)
        size >= @min_size && (@max_size.nil? || size <= @max_size)
      end

      def logger
        @logger ||= Steno.logger('cc.blobstore')
      end
    end
  end
end
