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
        start_instances_in_range(app, (0...app.instances))
      end

      def stop(app)
        dea_command("stop", :droplet => app.guid)
      end

      def change_running_instances(app, delta)
        if delta > 0
          range = (app.instances - delta...app.instances)
          start_instances_in_range(app, range)
        elsif delta < 0
          range = (app.instances...app.instances - delta)
          stop_instances_in_range(app, range)
        end
      end

      private

      def start_instances_in_range(app, idx_range)
        msg = start_app_message(app)
        idx_range.each do |idx|
          msg[:index] = idx
          dea_id = dea_pool.find_dea(app.memory, app.runtime.name)
          if dea_id
            dea_command("#{dea_id}.start", msg)
          else
            logger.error "no resources available #{msg}"
          end
        end
      end

      def stop_instances_in_range(app, idx_range)
        dea_command("stop",
                    :droplet => app.guid,
                    :version => app.version,
                    :indices => idx_range.to_a)
      end

      def start_app_message(app)
        # TODO: add debug and console support
        {
          :droplet => app.guid,
          :name => app.name,
          :uris => [xxx_uri_for_app(app)], # TODO app.mapped_urls
          :runtime => app.runtime.name,
          :framework => app.framework.name,
          :prod => app.production,
          :sha1 => app.droplet_hash,
          :executableFile => AppStager.droplet_path(app),
          :executableUri => LegacyStaging.droplet_uri(app.guid),
          :version => app.version,
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

      def dea_command(cmd, args)
        subject = "dea.#{cmd}"
        logger.debug "sending '#{subject}' with '#{args}'"
        json = Yajl::Encoder.encode(args)
        message_bus.publish(subject, json)
      end

      # FIXME: this is a very temporary hack to test out dea integration
      def xxx_uri_for_app(app)
        @base_uri ||= config[:external_domain].sub(/^\s*[^\.]+/,'')
        "#{app.guid}#{@base_uri}"
      end

      def logger
        @logger ||= Steno.logger("cc.dea.client")
      end
    end
  end
end
