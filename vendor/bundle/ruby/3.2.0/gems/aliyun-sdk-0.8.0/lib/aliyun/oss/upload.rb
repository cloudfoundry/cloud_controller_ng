# -*- encoding: utf-8 -*-

module Aliyun
  module OSS
    module Multipart
      ##
      # A multipart upload transaction
      #
      class Upload < Transaction

        include Common::Logging

        PART_SIZE = 10 * 1024 * 1024
        READ_SIZE = 16 * 1024
        NUM_THREAD = 10

        def initialize(protocol, opts)
          args = opts.dup
          @protocol = protocol
          @progress = args.delete(:progress)
          @file = args.delete(:file)
          @cpt_file = args.delete(:cpt_file)
          super(args)

          @file_meta = {}
          @num_threads = options[:threads] || NUM_THREAD
          @all_mutex = Mutex.new
          @parts = []
          @todo_mutex = Mutex.new
          @todo_parts = []
        end

        # Run the upload transaction, which includes 3 stages:
        # * 1a. initiate(new upload) and divide parts
        # * 1b. rebuild states(resumed upload)
        # * 2.  upload each unfinished part
        # * 3.  commit the multipart upload transaction
        def run
          logger.info("Begin upload, file: #{@file}, "\
                      "checkpoint file: #{@cpt_file}, "\
                      "threads: #{@num_threads}")

          # Rebuild transaction states from checkpoint file
          # Or initiate new transaction states
          rebuild

          # Divide the file to upload into parts to upload separately
          divide_parts if @parts.empty?

          # Upload each part
          @todo_parts = @parts.reject { |p| p[:done] }

          (1..@num_threads).map {
            Thread.new {
              loop {
                p = sync_get_todo_part
                break unless p
                upload_part(p)
              }
            }
          }.map(&:join)

          # Commit the multipart upload transaction
          commit

          logger.info("Done upload, file: #{@file}")
        end

        # Checkpoint structures:
        # @example
        #   states = {
        #     :id => 'upload_id',
        #     :file => 'file',
        #     :file_meta => {
        #       :mtime => Time.now,
        #       :md5 => 1024
        #     },
        #     :parts => [
        #       {:number => 1, :range => [0, 100], :done => false},
        #       {:number => 2, :range => [100, 200], :done => true}
        #     ],
        #     :md5 => 'states_md5'
        #   }
        def checkpoint
          logger.debug("Begin make checkpoint, disable_cpt: "\
                       "#{options[:disable_cpt] == true}")

          ensure_file_not_changed

          parts = sync_get_all_parts
          states = {
            :id => id,
            :file => @file,
            :file_meta => @file_meta,
            :parts => parts
          }

          # report progress
          if @progress
            done = parts.count { |p| p[:done] }
            @progress.call(done.to_f / parts.size) if done > 0
          end

          write_checkpoint(states, @cpt_file) unless options[:disable_cpt]

          logger.debug("Done make checkpoint, states: #{states}")
        end

        private
        # Commit the transaction when all parts are succefully uploaded
        # @todo handle undefined behaviors: commit succeeds in server
        #  but return error in client
        def commit
          logger.info("Begin commit transaction, id: #{id}")

          parts = sync_get_all_parts.map{ |p|
            Part.new(:number  => p[:number], :etag => p[:etag])
          }
          @protocol.complete_multipart_upload(
            bucket, object, id, parts, @options[:callback])

          File.delete(@cpt_file) unless options[:disable_cpt]

          logger.info("Done commit transaction, id: #{id}")
        end

        # Rebuild the states of the transaction from checkpoint file
        def rebuild
          logger.info("Begin rebuild transaction, checkpoint: #{@cpt_file}")

          if options[:disable_cpt] || !File.exists?(@cpt_file)
            initiate
          else
            states = load_checkpoint(@cpt_file)

            if states[:file_md5] != @file_meta[:md5]
              fail FileInconsistentError.new("The file to upload is changed.")
            end

            @id = states[:id]
            @file_meta = states[:file_meta]
            @parts = states[:parts]
          end

          logger.info("Done rebuild transaction, states: #{states}")
        end

        def initiate
          logger.info("Begin initiate transaction")

          @id = @protocol.initiate_multipart_upload(bucket, object, options)
          @file_meta = {
            :mtime => File.mtime(@file),
            :md5 => get_file_md5(@file)
          }
          checkpoint

          logger.info("Done initiate transaction, id: #{id}")
        end

        # Upload a part
        def upload_part(p)
          logger.debug("Begin upload part: #{p}")

          result = nil
          File.open(@file) do |f|
            range = p[:range]
            pos = range.first
            f.seek(pos)

            result = @protocol.upload_part(bucket, object, id, p[:number]) do |sw|
              while pos < range.at(1)
                bytes = [READ_SIZE, range.at(1) - pos].min
                sw << f.read(bytes)
                pos += bytes
              end
            end
          end

          sync_update_part(p.merge(done: true, etag: result.etag))

          checkpoint

          logger.debug("Done upload part: #{p}")
        end

        # Devide the file into parts to upload
        def divide_parts
          logger.info("Begin divide parts, file: #{@file}")

          max_parts = 10000
          file_size = File.size(@file)
          part_size = [@options[:part_size] || PART_SIZE, file_size / max_parts].max
          num_parts = (file_size - 1) / part_size + 1
          @parts = (1..num_parts).map do |i|
            {
              :number => i,
              :range => [(i-1) * part_size, [i * part_size, file_size].min],
              :done => false
            }
          end

          checkpoint

          logger.info("Done divide parts, parts: #{@parts}")
        end

        def sync_get_todo_part
          @todo_mutex.synchronize {
            @todo_parts.shift
          }
        end

        def sync_update_part(p)
          @all_mutex.synchronize {
            @parts[p[:number] - 1] = p
          }
        end

        def sync_get_all_parts
          @all_mutex.synchronize {
            @parts.dup
          }
        end

        # Ensure file not changed during uploading
        def ensure_file_not_changed
          return if File.mtime(@file) == @file_meta[:mtime]

          if @file_meta[:md5] != get_file_md5(@file)
            fail FileInconsistentError, "The file to upload is changed."
          end
        end
      end # Upload

    end # Multipart
  end # OSS
end # Aliyun
