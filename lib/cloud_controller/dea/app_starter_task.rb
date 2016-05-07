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

        @app.routes_changed = false
      end

      private

      attr_reader :dea_pool, :app, :blobstore_url_generator, :config

      def start_instances(indices)
        indices = Array(indices)
        insufficient_resources_error = false
        indices.each_slice(5) do |slice|
          begin
            callbacks = []
            slice.each do |idx|
              begin
                callback = start_instance_at_index(idx)
                callbacks << callback if callback
              rescue CloudController::Errors::ApiError => e
                if e.name == 'InsufficientRunningResourcesAvailable'
                  insufficient_resources_error = true
                else
                  raise e
                end
              end
            end
          ensure
            callbacks.each(&:call)
          end
        end

        raise CloudController::Errors::ApiError.new_from_details('InsufficientRunningResourcesAvailable') if insufficient_resources_error
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
