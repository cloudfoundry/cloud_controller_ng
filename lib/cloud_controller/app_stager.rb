# Copyright (c) 2009-2012 VMware, Inc.

require "vcap/stager/client"
require "redis"
require "cloud_controller/staging_task_log"

module VCAP::CloudController
  module AppStager
    class << self
      attr_reader :config

      def configure(config, redis_client = nil)
        @config = config
        @redis_client = redis_client || Redis.new(
          :host => @config[:redis][:host],
          :port => @config[:redis][:port],
          :password => @config[:redis][:password])
      end

      def stage_app(app)
        logger.debug "staging #{app.guid}"
        LegacyStaging.with_upload_handle(app.guid) do |handle|
          results = EM.schedule_sync do |promise|
            client = VCAP::Stager::Client::EmAware.new(MessageBus.nats.client, queue)
            deferrable = client.stage(staging_request(app), staging_timeout)

            deferrable.errback do |e|
              logger.error "staging #{app.guid} error #{e}"
              raise Errors::StagingError.new(e)
            end

            deferrable.callback do |resp|
              logger.debug "staging #{app.guid} complete #{resp}"
              promise.deliver(resp)
            end
          end

          StagingTaskLog.new(app.guid, results[:task_log], @redis_client).save
          upload_path = handle.upload_path
          droplet_hash = Digest::SHA1.file(upload_path).hexdigest
          FileUtils.mv(upload_path, droplet_path(app))
          app.droplet_hash = droplet_hash
        end

        logger.info "staging for #{app.guid} complete"
      end

      def droplet_path(app)
        File.join(droplets_path, "droplet_#{app.guid}")
      end

      private

      def staging_request(app)
        {
          :app_id       => app.guid,
          :properties   => staging_task_properties(app),
          :download_uri => LegacyStaging.app_uri(app.guid),
          :upload_uri   => LegacyStaging.droplet_uri(app.guid)
        }
      end

      def staging_task_properties(app)
        {
          :services    => app.service_bindings.map { |sb| service_binding_to_staging_request(sb) },
          :framework   => app.framework.name,
          :runtime     => app.runtime.name,
          :resources   => {
            :memory => app.memory,
            :disk   => app.disk_quota,
            :fds    => app.file_descriptors
          },
          :environment => app.environment_json,
          :meta => {} # TODO
        }
      end

      def service_binding_to_staging_request(sb)
        {
          :label        => sb.service_instance.service.label,
          :tabs         => {}, # TODO: can this be removed?
          :name         => sb.service_instance.name,
          :credentials  => sb.credentials,
          :options      => sb.binding_options || {},
          :plan         => sb.service_instance.service_plan.name,
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
