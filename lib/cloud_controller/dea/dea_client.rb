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

      def find_instances(app, options = {})
        message = { :droplet => app.guid }
        message.merge!(options)

        dea_request("find.droplet", message,
                    :expected => app.instances,
                    :timeout => 2)
      end

      def get_file_url(app, instance, path = nil)
        if app.stopped?
          msg = "Request failed for app: #{app.name}, instance: #{instance}"
          msg << " and path: #{path || '/'} as the app is in stopped state."

          raise FileError.new(msg)
        end

        if instance < 0 || instance >= app.instances
          msg = "Request failed for app: #{app.name}, instance: #{instance}"
          msg << " and path: #{path || '/'} as the instance is out of range."

          raise FileError.new(msg)
        end

        search_options = {
          :indices => [instance],
          :states => [:STARTING, :RUNNING, :CRASHED],
          :version => app.version
        }

        if instance_found = find_specific_instance(app, search_options)
          url = "#{instance_found[:file_uri]}#{instance_found[:staged]}"
          url << "/#{path}"
          return [url, instance_found[:credentials]]
        end

        msg = "Request failed for app: #{app.name}, instance: #{instance}"
        msg << " and path: #{path || '/'} as the instance is not found."

        raise FileError.new(msg)
      end

      def find_stats(app)
        if app.stopped?
          msg = "Request failed for app: #{app.name}"
          msg << " as the app is in stopped state."

          raise StatsError.new(msg)
        end

        search_options = {
          :include_stats => true,
          :states => [:RUNNING],
          :version => app.version,
        }

        running_instances = find_instances(app, search_options)

        stats = {} # map of instance index to stats.
        running_instances.each do |instance|
          stats[instance[:index]] = {
            :state => instance[:state],
            :stats => instance[:stats],
          }
        end

        # we may not have received responses from all instances.
        app.instances.times do |index|
          unless stats[index]
            stats[index] = {
              :state => "DOWN",
              :since => Time.now.to_i,
            }
          end
        end

        stats
      end

      # @param [Enumerable, #each] indices an Enumerable of indices / indexes
      # @param [Hash] message_override a hash which will be merged into the
      #   message sent over to dea, Health Manager's flapping flag should go in
      #   here. If you are not sure, specify an empty hash ({})
      def start_instances_with_message(app, indices, message_override)
        msg = start_app_message(app)

        indices.each do |idx|
          msg[:index] = idx
          dea_id = dea_pool.find_dea(app.memory, app.runtime.name)
          if dea_id
            dea_publish("#{dea_id}.start", msg.merge(message_override))
          else
            logger.error "no resources available #{msg}"
          end
        end
      end

      # @param [Array] indices an Enumerable of integer indices
      def stop_instances(app, indices)
        dea_publish("stop",
                    :droplet => app.guid,
                    :version => app.version,
                    :indices => indices,
                   )
      end

      private

      # @param [Enumerable, #each] indices the range / sequence of instances to start
      def start_instances_in_range(app, indices)
        start_instances_with_message(app, indices, {})
      end

      # @param [Enumerable, #to_a] indices the range / sequence of instances to stop
      def stop_instances_in_range(app, indices)
        stop_instances(app, indices.to_a)
      end

      def start_app_message(app)
        # TODO: add debug and console support
        {
          :droplet => app.guid,
          :name => app.name,
          :uris => app.uris,
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
          :cc_partition => config[:cc_partition],
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
        subject = "dea.#{cmd}"
        msg = "sending subject: '#{subject}' with args: '#{args}'"
        msg << " and opts: '#{opts}'"
        logger.debug msg
        json = Yajl::Encoder.encode(args)

        response = message_bus.request(subject, json, opts)
        parsed_response = []
        response.each do |json_str|
          parsed_response << Yajl::Parser.parse(json_str,
                                                :symbolize_keys => true)
        end

        parsed_response
      end

      def logger
        @logger ||= Steno.logger("cc.dea.client")
      end
    end
  end
end
