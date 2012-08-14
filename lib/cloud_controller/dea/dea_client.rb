# Copyright (c) 2009-2012 VMware, Inc.

require "vcap/stager/client"

module VCAP::CloudController
  module DeaClient
    class << self
      attr_reader :config, :message_bus, :dea_pool

      def configure(config, message_bus = MessageBus, dea_pool = DeaPool)
        @config = config
        @message_bus = message_bus
        @dea_pool = dea_pool
      end

      def start(app)
        start_instances(app, app.instances)
      end

      private

      def start_instances(app, num, next_index = 0)
        msg = start_app_message(app)
        num.times do |i|
          # TODO: audit dea and HM to see if we can use guids for this instead
          # of sequential indices
          msg[:index] = next_index + i
          dea_id = dea_pool.find_dea(app.memory, app.runtime.name)
          if dea_id
            json = Yajl::Encoder.encode(msg)
            logger.debug "sending start message '#{json}' to dea #{dea_id}"
            message_bus.publish("dea.#{dea_id}.start", json)
          else
            logger.error "no resources available #{msg}"
          end
        end
      end

      def start_app_message(app)
        # TODO: add debug and console support
        {
          :droplet => app.guid,
          :name => app.name,
          :uris => [], # TODO app.mapped_urls
          :runtime => app.runtime.name,
          :framework => app.framework.name,
          :prod => app.production,
          :sha1 => app.droplet_hash,
          :executableFile => AppStager.droplet_path(app),
          :executableUri => LegacyStaging.droplet_uri(app.guid),
          :version => app.droplet_hash,
          :services => app.service_bindings.map do |sb|
            svc = sb.service_instance.service_plan.service
            {
              :name => sb.service_instance.name,
              :label => svc.label,
              :vendor => svc.provider,
              :version => svc.version,
              :plan => sb.service_instance.service_plan.name,
              :credentials => sb.credentials
            }
          end,
          :limits => {
            :mem => app.memory,
            :disk => app.disk_quota,
            :fds => app.file_descriptors
          },
          :env => {} # TODO
        }
      end

      def logger
        @logger ||= Steno.logger("cc.dea.client")
      end
    end
  end
end
