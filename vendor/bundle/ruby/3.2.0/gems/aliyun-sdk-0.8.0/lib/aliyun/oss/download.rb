# -*- encoding: utf-8 -*-

module Aliyun
  module OSS
    module Multipart
      ##
      # A multipart download transaction
      #
      class Download < Transaction

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

          @object_meta = {}
          @num_threads = options[:threads] || NUM_THREAD
          @all_mutex = Mutex.new
          @parts = []
          @todo_mutex = Mutex.new
          @todo_parts = []
        end

        # Run the download transaction, which includes 3 stages:
        # * 1a. initiate(new downlaod) and divide parts
        # * 1b. rebuild states(resumed download)
        # * 2.  download each unfinished part
        # * 3.  combine the downloaded parts into the final file
        def run
          logger.info("Begin download, file: #{@file}, "\
                      "checkpoint file: #{@cpt_file}, "\
                      "threads: #{@num_threads}")

          # Rebuild transaction states from checkpoint file
          # Or initiate new transaction states
          rebuild

          # Divide the target object into parts to download by ranges
          divide_parts if @parts.empty?

          # Download each part(object range)
          @todo_parts = @parts.reject { |p| p[:done] }

          (1..@num_threads).map {
            Thread.new {
              loop {
                p = sync_get_todo_part
                break unless p
                download_part(p)
              }
            }
          }.map(&:join)

          # Combine the parts into the final file
          commit

          logger.info("Done download, file: #{@file}")
        end

        # Checkpoint structures:
        # @example
        #   states = {
        #     :id => 'download_id',
        #     :file => 'file',
        #     :object_meta => {
        #       :etag => 'xxx',
        #       :size => 1024
        #     },
        #     :parts => [
        #       {:number => 1, :range => [0, 100], :md5 => 'xxx', :done => false},
        #       {:number => 2, :range => [100, 200], :md5 => 'yyy', :done => true}
        #     ],
        #     :md5 => 'states_md5'
        #   }
        def checkpoint
          logger.debug("Begin make checkpoint, disable_cpt: "\
                       "#{options[:disable_cpt] == true}")

          ensure_object_not_changed

          parts = sync_get_all_parts
          states = {
            :id => id,
            :file => @file,
            :object_meta => @object_meta,
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
        # Combine the downloaded parts into the final file
        # @todo avoid copy all part files
        def commit
          logger.info("Begin commit transaction, id: #{id}")

          parts = sync_get_all_parts
          # concat all part files into the target file
          File.open(@file, 'wb') do |w|
            parts.sort{ |x, y| x[:number] <=> y[:number] }.each do |p|
              File.open(get_part_file(p)) do |r|
                  w.write(r.read(READ_SIZE)) until r.eof?
              end
            end
          end

          File.delete(@cpt_file) unless options[:disable_cpt]
          parts.each{ |p| File.delete(get_part_file(p)) }

          logger.info("Done commit transaction, id: #{id}")
        end

        # Rebuild the states of the transaction from checkpoint file
        def rebuild
          logger.info("Begin rebuild transaction, checkpoint: #{@cpt_file}")

          if options[:disable_cpt] || !File.exists?(@cpt_file)
            initiate
          else
            states = load_checkpoint(@cpt_file)

            states[:parts].select{ |p| p[:done] }.each do |p|
              part_file = get_part_file(p)

              unless File.exist?(part_file)
                fail PartMissingError, "The part file is missing: #{part_file}."
              end

              if p[:md5] != get_file_md5(part_file)
                fail PartInconsistentError,
                     "The part file is changed: #{part_file}."
              end
            end

            @id = states[:id]
            @object_meta = states[:object_meta]
            @parts = states[:parts]
          end

          logger.info("Done rebuild transaction, states: #{states}")
        end

        def initiate
          logger.info("Begin initiate transaction")

          @id = generate_download_id
          obj = @protocol.get_object_meta(bucket, object)
          @object_meta = {
            :etag => obj.etag,
            :size => obj.size
          }
          checkpoint

          logger.info("Done initiate transaction, id: #{id}")
        end

        # Download a part
        def download_part(p)
          logger.debug("Begin download part: #{p}")

          part_file = get_part_file(p)
          File.open(part_file, 'wb') do |w|
            @protocol.get_object(
              bucket, object,
              @options.merge(range: p[:range])) { |chunk| w.write(chunk) }
          end

          sync_update_part(p.merge(done: true, md5: get_file_md5(part_file)))

          checkpoint

          logger.debug("Done download part: #{p}")
        end

        # Devide the object to download into parts to download
        def divide_parts
          logger.info("Begin divide parts, object: #{@object}")

          max_parts = 100
          object_size = @object_meta[:size]
          part_size =
            [@options[:part_size] || PART_SIZE, object_size / max_parts].max
          num_parts = (object_size - 1) / part_size + 1
          @parts = (1..num_parts).map do |i|
            {
              :number => i,
              :range => [(i - 1) * part_size, [i * part_size, object_size].min],
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
        def ensure_object_not_changed
          obj = @protocol.get_object_meta(bucket, object)
          unless obj.etag == @object_meta[:etag]
            fail ObjectInconsistentError,
                 "The object to download is changed: #{object}."
          end
        end

        # Generate a download id
        def generate_download_id
          "download_#{bucket}_#{object}_#{Time.now.to_i}"
        end

        # Get name for part file
        def get_part_file(p)
          "#{@file}.part.#{p[:number]}"
        end
      end # Download

    end # Multipart
  end # OSS
end # Aliyun
