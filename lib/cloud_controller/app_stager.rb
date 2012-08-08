# Copyright (c) 2009-2012 VMware, Inc.

require "vcap/stager/client"

module VCAP::CloudController
  module AppStager
    class << self
      attr_reader :config

      def configure(config)
        @config = config
      end

      def stage_app(app)
        LegacyStaging.with_upload_handle(app) do |handle|
          EM.schedule_sync do |promise|
            client = VCAP::Stager::Client::EmAware.new(MessageBus.nats.client, queue)
            deferrable = client.stage(staging_request(app), staging_timeout)

            deferrable.errback do |e|
              raise Errors::StagingError.new(e)
            end

            deferrable.callback do |resp|
              promise.deliver(resp)
            end
          end
        end

        # TODO: save staging log, update app

        logger.info "staging for #{app.guid} complete"
      end

      private

      def staging_request(app)
        {
          :app_id       => app.guid,
          :properties   => staging_task_properties(app),
          :download_uri => LegacyStaging.download_app_uri(app.guid),
          :upload_uri   => LegacyStaging.upload_droplet_uri(app.guid)
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
        @config[:staging] && [:max_staging_runtime] || 120
      end

      def logger
        @logger ||= Steno.logger("cc.app_stager")
      end
    end
  end
end
