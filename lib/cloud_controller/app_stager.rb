# Copyright (c) 2009-2012 VMware, Inc.

require "vcap/stager/client"
require "redis"
require "cloud_controller/staging_task_log"
require "cloud_controller/multi_response_nats_request"

module VCAP::CloudController
  module AppStager
    class Response
      def initialize(response)
        @response = response
      end

      def log
        @response["task_log"]
      end

      def streaming_log_url
        @response["task_streaming_log_url"]
      end
    end

    class << self
      attr_reader :config, :message_bus

      def configure(config, message_bus, redis_client = nil)
        @config = config
        @message_bus = message_bus
        @redis_client = redis_client || Redis.new(
          :host => @config[:redis][:host],
          :port => @config[:redis][:port],
          :password => @config[:redis][:password]
        )
      end

      def stage_app(app, options={}, &completion_callback)
        current_droplet_hash = app.droplet_hash

        responses = MultiResponseNatsRequest.new(MessageBus.instance.nats.client, queue)
        upload_handle = LegacyStaging.create_handle(app.guid)

        staging_full_result = EM.schedule_sync do |promise|
          # First message might be SYNC or ASYNC staging response
          # since stager might not support async staging process.
          # First response is blocking stage_app.
          responses.on_response(staging_timeout) do |response, error|
            staging_error!(app, response, error, upload_handle)
            ensure_staging_is_current!(app, current_droplet_hash, upload_handle)

            stager_response = Response.new(response)
            if stager_response.streaming_log_url
              promise.deliver(stager_response)
            else
              responses.ignore_subsequent_responses

              # Defer potentially expensive operation
              # to avoid executing on reactor thread
              EM.defer do
                staging_completion(app, stager_response, upload_handle)
                completion_callback.call if completion_callback
                promise.deliver(stager_response)
              end
            end
          end

          # Second message is received after app staging finished and
          # droplet was uploaded to the CC.
          # Second response does NOT block stage_app
          responses.on_response(staging_timeout) do |response, error|
            responses.ignore_subsequent_responses

            staging_error!(app, response, error, upload_handle)
            ensure_staging_is_current!(app, current_droplet_hash, upload_handle)

            # Defer potentially expensive operation
            # to avoid executing on reactor thread
            EM.defer do
              stager_response = Response.new(response)
              staging_completion(app, stager_response, upload_handle)
              completion_callback.call if completion_callback
            end
          end

          responses.request(staging_request(app, options[:async]))
        end

        staging_full_result
      end

      def delete_droplet(app)
        LegacyStaging.delete_droplet(app.guid)
      end

      def staging_request(app, async)
        {
          :app_id => app.guid,
          :properties => staging_task_properties(app),
          :download_uri => LegacyStaging.app_uri(app.guid),
          :upload_uri => LegacyStaging.droplet_upload_uri(app.guid),
          :async => async,
        }
      end

      private

      def staging_error!(app, response, error, upload_handle)
        if error
          raise Errors::StagingError, "failed to stage application:\n#{error}"
        elsif response["error"]
          raise Errors::StagingError, "failed to stage application:\n#{response["error"]}"
        end
      rescue
        LegacyStaging.destroy_handle(upload_handle)
        raise
      end

      def ensure_staging_is_current!(app, current_droplet_hash, upload_handle)
        # Reload to find other updates of droplet hash
        # which means that our staging process should not update the app
        app.refresh
        unless app.droplet_hash == current_droplet_hash
          raise Errors::StagingError, "failed to stage because app changed while staging"
        end
      rescue
        LegacyStaging.destroy_handle(upload_handle)
        raise
      end

      def staging_completion(app, stager_response, upload_handle)
        StagingTaskLog.new(app.guid, stager_response.log, @redis_client).save

        droplet_hash = Digest::SHA1.file(upload_handle.upload_path).hexdigest
        LegacyStaging.store_droplet(app.guid, upload_handle.upload_path)

        app.droplet_hash = droplet_hash
        app.save
      ensure
        LegacyStaging.destroy_handle(upload_handle)
      end

      def staging_task_properties(app)
        {
          :services    => app.service_bindings.map { |sb| service_binding_to_staging_request(sb) },
          :framework      => app.framework.name,
          :framework_info => app.framework.internal_info,

          :runtime        => app.runtime.name,
          :runtime_info   => app.runtime.internal_info.merge(
            :name => app.runtime.name
          ),

          :buildpack => app.buildpack,

          :resources   => {
            :memory => app.memory,
            :disk   => app.disk_quota,
            :fds    => app.file_descriptors
          },

          :environment => (app.environment_json || {}).map {|k,v| "#{k}=#{v}"},
          :meta => app.metadata
        }
      end

      def service_binding_to_staging_request(sb)
        instance = sb.service_instance
        plan = instance.service_plan
        service = plan.service

        {
          :label        => "#{service.label}-#{service.version}",
          :tags         => {}, # TODO: can this be removed?
          :name         => instance.name,
          :credentials  => sb.credentials,
          :options      => sb.binding_options || {},
          :plan         => instance.service_plan.name,
          :plan_options => {} # TODO: can this be removed?
        }
      end

      def queue
        @config[:staging] && @config[:staging][:queue] || "staging"
      end

      def staging_timeout
        @config[:staging] && @config[:staging][:max_staging_runtime] || 120
      end

      def droplets_path
        unless @droplets_path
          # TODO: remove this tmpdir.  It is for use when running under vcap
          # for development
          @droplets_path = @config[:directories] && @config[:directories][:droplets]
          @droplets_path ||= Dir.mktmpdir
          FileUtils.mkdir_p(@droplets_path) unless File.directory?(@droplets_path)
        end
        @droplets_path
      end

      def logger
        @logger ||= Steno.logger("cc.app_stager")
      end
    end
  end
end
