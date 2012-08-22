# Copyright (c) 2009-2012 VMware, Inc.

require "vcap/stager/client"
require "cloud_controller/errors"

module VCAP::CloudController
  module DeaClient
    class << self
      include VCAP::CloudController::Errors

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
        dea_publish("stop", :droplet => app.guid)
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

      def find_specific_instance(app, options = {})
        message = { :droplet => app.guid }
        message.merge!(options)

        dea_request("find.droplet", message).first
      end

      def get_file_url(app, instance, path = nil)
        if app.stopped?
          msg = "Request failed for app: #{app.name}, instance: #{instance}"
          msg << " and path: #{path} as the app is in stopped state."

          raise FileError.new(msg)
        end

        search_options = {}

        if instance < 0 || instance >= app.instances
          msg = "Request failed for app: #{app.name}, instance: #{instance}"
          msg << " and path: #{path} as the instance is out of range."

          raise FileError.new(msg)
        end

        search_options[:indices] = [instance]
        search_options[:states] = [:STARTING, :RUNNING, :CRASHED]
        search_options[:version] = app.version

        if instance_found = find_specific_instance(app, search_options)
          url = "#{instance_found[:file_uri]}#{instance_found[:staged]}"
          url << "/#{path}"
          return [url, instance_found[:credentials]]
        end

        msg = "Request failed for app: #{app.name}, instance: #{instance}"
        msg << " and path: #{path} as the instance is not found."

        raise FileError.new(msg)
      end

      private

      def start_instances_in_range(app, idx_range)
        msg = start_app_message(app)
        idx_range.each do |idx|
          msg[:index] = idx
          dea_id = dea_pool.find_dea(app.memory, app.runtime.name)
          if dea_id
            dea_publish("#{dea_id}.start", msg)
          else
            logger.error "no resources available #{msg}"
          end
        end
      end

      def stop_instances_in_range(app, idx_range)
        dea_publish("stop",
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

      def dea_publish(cmd, args)
        subject = "dea.#{cmd}"
        logger.debug "sending '#{subject}' with '#{args}'"
        json = Yajl::Encoder.encode(args)

        message_bus.publish(subject, json)
      end

      def dea_request(cmd, args, opts = {})
        expected = opts[:expected] || 1

        subject = "dea.#{cmd}"
        logger.debug "sending '#{subject}' with '#{args}'"
        json = Yajl::Encoder.encode(args)

        response = message_bus.request(subject, json, :expected => expected)
        parsed_response = []
        response.each do |json_str|
          parsed_response << Yajl::Parser.parse(json_str,
                                                :symbolize_keys => true)
        end

        parsed_response
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
