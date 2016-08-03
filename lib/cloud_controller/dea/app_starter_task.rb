module VCAP::CloudController
  module Dea
    class AppStarterTask
      def initialize(app, blobstore_url_generator, config)
        @app = app
        @blobstore_url_generator = blobstore_url_generator
        @config = config
        @dea_pool = Dea::Client.dea_pool
      end

      def start(options={})
        if options[:specific_instances]
          start_instances(options[:specific_instances])
        else
          instances_to_start = options[:instances_to_start] || @app.instances
          start_instances((@app.instances - instances_to_start)...@app.instances)
        end
      end

      private

      attr_reader :dea_pool, :app, :blobstore_url_generator, :config

      def start_instances(indices)
        indices = Array(indices)

        begin
          indices.each_slice(5) do |indexes|
            attempt_start_for_indexes(indexes, 1)
          end
        rescue CloudController::Errors::ApiError => e
          if e.name == 'InsufficientRunningResourcesAvailable'
            raise CloudController::Errors::ApiError.new_from_details('InsufficientRunningResourcesAvailable')
          else
            raise e
          end
        end
      end

      def attempt_start_for_indexes(indexes, attempt)
        callbacks = []
        retry_indexes = []

        begin
          indexes.each do |idx|
            callback = start_instance_at_index(idx)
            callbacks << { callback: callback, index: idx } if callback
          end
        ensure
          callbacks.each do |cb|
            status = cb[:callback].call
            if status == 503
              retry_indexes << cb[:index]
            end
          end

          attempt += 1
          logger.warn 'dea-client.attempt-start-for-indexes', attempt: attempt
          attempt_start_for_indexes(retry_indexes, attempt) unless retry_indexes.empty? || attempt > 3
        end
      end

      def start_instance_at_index(index)
        start_message = Dea::StartAppMessage.new(app, index, config, blobstore_url_generator)

        unless start_message.has_app_package?
          logger.error 'dea-client.no-package-found', guid: app.guid
          raise CloudController::Errors::ApiError.new_from_details('AppPackageNotFound', app.guid)
        end

        dea = dea_pool.find_dea(mem: app.memory, disk: app.disk_quota, stack: app.stack.name, app_id: app.guid)
        if dea.nil?
          logger.error 'dea-client.no-resources-available', message: scrub_sensitive_fields(start_message)
          raise CloudController::Errors::ApiError.new_from_details('InsufficientRunningResourcesAvailable')
        end

        callback = Dea::Client.send_start(dea, start_message)
        dea_pool.mark_app_started(dea_id: dea.dea_id, app_id: app.guid)
        dea_pool.reserve_app_memory(dea.dea_id, app.memory)
        callback
      end

      def scrub_sensitive_fields(message)
        scrubbed_message = message.dup
        scrubbed_message.delete(:services)
        scrubbed_message.delete(:executableUri)
        scrubbed_message.delete(:env)
        scrubbed_message
      end

      def logger
        @logger ||= Steno.logger('cc.dea.app_starter_task')
      end
    end
  end
end
