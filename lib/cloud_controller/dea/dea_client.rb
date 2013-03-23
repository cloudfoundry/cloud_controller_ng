# Copyright (c) 2009-2012 VMware, Inc.

require "vcap/stager/client"
require "vcap/errors"

module VCAP::CloudController
  module DeaClient
    class FileUriResult < Struct.new(:file_uri_v1, :file_uri_v2, :credentials)
      def initialize(opts = {})
        if opts[:file_uri_v2]
          self.file_uri_v2 = opts[:file_uri_v2]
        end
        if opts[:file_uri_v1]
          self.file_uri_v1 = opts[:file_uri_v1]
        end
        if opts[:credentials]
          self.credentials = opts[:credentials]
        end
      end
    end

    class << self
      include VCAP::Errors

      attr_reader :config, :message_bus, :dea_pool

      def configure(config, message_bus, dea_pool)
        @config = config
        @message_bus = message_bus
        @dea_pool = dea_pool
      end

      def run
        @dea_pool.register_subscriptions
      end

      def start(app)
        start_instances_in_range(app, (0...app.instances))
        app.routes_changed = false
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
          stop_indices_in_range(app, range)
        end
      end

      def find_specific_instance(app, options = {})
        message = { :droplet => app.guid }
        message.merge!(options)

        dea_request("find.droplet", message, :timeout => 2).first
      end

      def find_instances(app, message_options = {}, request_options = {})
        message = { :droplet => app.guid }
        message.merge!(message_options)

        request_options[:expected] ||= app.instances
        request_options[:timeout] ||= 2

        dea_request("find.droplet", message, request_options)
      end

      def get_file_uri_for_instance(app, path, instance)
        if instance < 0 || instance >= app.instances
          msg = "Request failed for app: #{app.name}, instance: #{instance}"
          msg << " and path: #{path || '/'} as the instance is out of range."

          raise FileError.new(msg)
        end

        search_opts = {
          :indices => [instance],
          :version => app.version
        }

        result = get_file_uri(app, path, search_opts)
        unless result
          msg = "Request failed for app: #{app.name}, instance: #{instance}"
          msg << " and path: #{path || '/'} as the instance is not found."

          raise FileError.new(msg)
        end
        result
      end

      def get_file_uri_for_instance_id(app, path, instance_id)
        result = get_file_uri(app, path, :instance_ids => [instance_id])
        unless result
          msg = "Request failed for app: #{app.name}, instance_id: #{instance_id}"
          msg << " and path: #{path || '/'} as the instance_id is not found."

          raise FileError.new(msg)
        end
        result
      end

      def find_stats(app, opts = {})
        opts = { :allow_stopped_state => false }.merge(opts)

        if app.stopped?
          unless opts[:allow_stopped_state]
            msg = "Request failed for app: #{app.name}"
            msg << " as the app is in stopped state."

            raise StatsError.new(msg)
          end

          return {}
        end

        search_options = {
          :include_stats => true,
          :states => [:RUNNING],
          :version => app.version,
        }

        running_instances = find_instances(app, search_options)

        stats = {} # map of instance index to stats.
        running_instances.each do |instance|
          index = instance[:index]
          if index >= 0 && index < app.instances
            stats[index] = {
              :state => instance[:state],
              :stats => instance[:stats],
            }
          end
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

      def find_all_instances(app)
        if app.stopped?
          msg = "Request failed for app: #{app.name}"
          msg << " as the app is in stopped state."

          raise InstancesError.new(msg)
        end

        num_instances = app.instances
        message = {
          :state => :FLAPPING,
          :version => app.version,
        }

        flapping_indices = HealthManagerClient.find_status(app, message)

        all_instances = {}
        if flapping_indices && flapping_indices[:indices]
          flapping_indices[:indices].each do |entry|
            index = entry[:index]
            if index >= 0 && index < num_instances
              all_instances[index] = {
                :state => "FLAPPING",
                :since => entry[:since],
              }
            end
          end
        end

        message = {
          :states => [:STARTING, :RUNNING],
          :version => app.version,
        }

        expected_running_instances = num_instances - all_instances.length
        if expected_running_instances > 0
          request_options = { :expected => expected_running_instances }
          running_instances = find_instances(app, message, request_options)

          running_instances.each do |instance|
            index = instance[:index]
            if index >= 0 && index < num_instances
              all_instances[index] = {
                :state => instance[:state],
                :since => instance[:state_timestamp],
                :debug_ip => instance[:debug_ip],
                :debug_port => instance[:debug_port],
                :console_ip => instance[:console_ip],
                :console_port => instance[:console_port]
              }
            end
          end
        end

        num_instances.times do |index|
          unless all_instances[index]
            all_instances[index] = {
              :state => "DOWN",
              :since => Time.now.to_i,
            }
          end
        end

        all_instances
      end

      # @param [Enumerable, #each] indices an Enumerable of indices / indexes
      # @param [Hash] message_override a hash which will be merged into the
      #   message sent over to dea, Health Manager's flapping flag should go in
      #   here. If you are not sure, specify an empty hash ({})
      def start_instances_with_message(app, indices, message_override)
        msg = start_app_message(app)

        indices.each do |idx|
          msg[:index] = idx
          dea_id = dea_pool.find_dea(app.memory, app.stack.name)
          if dea_id
            dea_publish("#{dea_id}.start", msg.merge(message_override))
          else
            logger.error "no resources available #{msg}"
          end
        end
      end

      # @param [Array] indices an Enumerable of integer indices
      def stop_indices(app, indices)
        dea_publish("stop",
                    :droplet => app.guid,
                    :version => app.version,
                    :indices => indices,
                   )
      end

      # @param [Array] indices an Enumerable of guid instance ids
      def stop_instances(app, instances)
        dea_publish("stop",
                    :droplet => app.guid,
                    :instances => instances,
                   )
      end

      def update_uris(app)
        return unless app.staged?
        message = dea_update_message(app)
        dea_publish("update", message)
        app.routes_changed = false
      end

      private

      # @param [Enumerable, #each] indices the range / sequence of instances to start
      def start_instances_in_range(app, indices)
        start_instances_with_message(app, indices, {})
      end

      # @param [Enumerable, #to_a] indices the range / sequence of instances to stop
      def stop_indices_in_range(app, indices)
        stop_indices(app, indices.to_a)
      end

      # @return [FileUriResult]
      def get_file_uri(app, path, options)
        if app.stopped?
          msg = "Request failed for app: #{app.name} path: #{path || '/'} "
          msg << "as the app is in stopped state."

          raise FileError.new(msg)
        end

        search_options = {
          :states => [:STARTING, :RUNNING, :CRASHED],
          :path => path,
        }.merge(options)

        if instance_found = find_specific_instance(app, search_options)
          result = FileUriResult.new
          if instance_found[:file_uri_v2]
            result.file_uri_v2 = instance_found[:file_uri_v2]
          end

          uri_v1 = [instance_found[:file_uri], instance_found[:staged], "/", path].join("")
          result.file_uri_v1 = uri_v1
          result.credentials = instance_found[:credentials]

          return result
        end

        nil
      end

      def dea_update_message(app)
        {
          :droplet  => app.guid,
          :uris     => app.uris,
        }
      end

      def start_app_message(app)
        # TODO: add debug support
        {
          :droplet => app.guid,
          :name => app.name,
          :uris => app.uris,
          :prod => app.production,
          :sha1 => app.droplet_hash,
          :executableFile => "deprecated",
          :executableUri => LegacyStaging.droplet_download_uri(app.guid),
          :version => app.version,
          :services => app.service_bindings.map do |sb|
            svc = sb.service_instance.service_plan.service
            {
              :name => sb.service_instance.name,
              :label => "#{svc.label}-#{svc.version}",
              :plan => sb.service_instance.service_plan.name,
              :provider => svc.provider,
              :version => svc.version,
              :credentials => sb.credentials,
              :vendor => svc.label
            }
          end,
          :limits => {
            :mem => app.memory,
            :disk => app.disk_quota,
            :fds => app.file_descriptors
          },
          :cc_partition => config[:cc_partition],
          :env => (app.environment_json || {}).map {|k,v| "#{k}=#{v}"},
          :console => app.console,
          :debug => app.debug,
        }
      end

      def dea_publish(cmd, args = {})
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
