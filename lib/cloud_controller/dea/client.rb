require 'cloud_controller/dea/app_stopper'
require 'cloud_controller/dea/file_uri_result'

module VCAP::CloudController
  module Dea
    module Client
      ACTIVE_APP_STATES = [:RUNNING, :STARTING].freeze
      class << self
        include CloudController::Errors

        attr_reader :config, :message_bus, :dea_pool, :message_bus

        def configure(config, message_bus, dea_pool, blobstore_url_generator)
          @config = config
          @message_bus = message_bus
          @dea_pool = dea_pool
          @blobstore_url_generator = blobstore_url_generator
          @http_client = nil

          if config[:dea_client]
            client = HTTPClient.new
            client.connect_timeout = 5
            client.receive_timeout = 5
            client.send_timeout = 5
            client.keep_alive_timeout = 1

            ssl = client.ssl_config
            ssl.verify_mode = OpenSSL::SSL::VERIFY_PEER

            dea_config = config[:dea_client]
            ssl.set_client_cert_file(dea_config[:cert_file], dea_config[:key_file])

            ssl.clear_cert_store
            ssl.add_trust_ca(dea_config[:ca_file])

            @http_client = client
          end
        end

        def enabled?
          @http_client != nil
        end

        def stage(url, msg)
          raise ApiError.new_from_details('StagerError', 'Client not HTTP enabled') unless enabled?

          begin
            response = @http_client.post("#{url}/v1/stage", header: { 'Content-Type' => 'application/json' }, body: MultiJson.dump(msg))
            status = response.status
            return status if [202, 404, 503].include?(status)
          rescue => e
            raise ApiError.new_from_details('StagerError', "url: #{url}/v1/stage, error: #{e.message}")
          end

          raise ApiError.new_from_details('StagerError', "received #{status} from #{url}/v1/stage")
        end

        def run
          @dea_pool.register_subscriptions
        end

        def find_specific_instance(app, options={})
          message = { droplet: app.guid }
          message.merge!(options)

          dea_request_find_droplet(message, timeout: 2).first
        end

        def find_instances(app, message_options={}, request_options={})
          message = { droplet: app.guid }
          message.merge!(message_options)

          request_options[:result_count] ||= app.instances
          request_options[:timeout] ||= 2

          dea_request_find_droplet(message, request_options)
        end

        def find_all_instances(app)
          num_instances = app.instances
          all_instances = {}

          flapping_indices = health_manager_client.find_flapping_indices(app)

          flapping_indices.each do |entry|
            index = entry['index']
            if index >= 0 && index < num_instances
              all_instances[index] = {
                  state: 'FLAPPING',
                  since: entry['since'],
              }
            end
          end

          message = {
              states: [:STARTING, :RUNNING],
              version: app.version,
          }

          expected_running_instances = num_instances - all_instances.length
          if expected_running_instances > 0
            request_options = { expected: expected_running_instances }
            running_instances = find_instances(app, message, request_options)

            running_instances.each do |instance|
              index = instance['index']
              if index >= 0 && index < num_instances
                all_instances[index] = {
                    state: instance['state'],
                    since: instance['state_timestamp'],
                    debug_ip: instance['debug_ip'],
                    debug_port: instance['debug_port'],
                    console_ip: instance['console_ip'],
                    console_port: instance['console_port']
                }
              end
            end
          end

          num_instances.times do |index|
            unless all_instances[index]
              all_instances[index] = {
                  state: 'DOWN',
                  since: Time.now.utc.to_i,
              }
            end
          end

          all_instances
        end

        def change_running_instances(app, delta)
          if delta > 0
            range = (app.instances - delta...app.instances)
            Dea::AppStarterTask.new(app, @blobstore_url_generator, config).start(specific_instances: range)
          elsif delta < 0
            range = (app.instances...app.instances - delta)
            stop_indices(app, range.to_a)
          end
        end

        # @param [Enumerable, #each] indices an Enumerable of indices / indexes

        # @param [Array] indices an Enumerable of integer indices
        def stop_indices(app, indices)
          app_stopper.publish_stop(
            droplet: app.guid,
            version: app.version,
            indices: indices
          )
        end

        # @param [Array] indices an Enumerable of guid instance ids
        def stop_instances(app_guid, instances)
          app_stopper.publish_stop(
            droplet: app_guid,
            instances: Array(instances)
          )
        end

        def app_stopper
          AppStopper.new(message_bus)
        end

        def get_file_uri_for_active_instance_by_index(app, path, index)
          if index < 0 || index >= app.instances
            msg = "Request failed for app: #{app.name}, instance: #{index}"
            msg << " and path: #{path || '/'} as the instance is out of range."

            raise ApiError.new_from_details('FileError', msg)
          end

          search_criteria = {
              indices: [index],
              version: app.version,
              states: ACTIVE_APP_STATES
          }

          result = get_file_uri(app, path, search_criteria)
          unless result
            msg = "Request failed for app: #{app.name}, instance: #{index}"
            msg << " and path: #{path || '/'} as the instance is not found."

            raise ApiError.new_from_details('FileError', msg)
          end
          result
        end

        def get_file_uri_by_instance_guid(app, path, instance_id)
          result = get_file_uri(app, path, instance_ids: [instance_id])
          unless result
            msg = "Request failed for app: #{app.name}, instance_id: #{instance_id}"
            msg << " and path: #{path || '/'} as the instance_id is not found."

            raise ApiError.new_from_details('FileError', msg)
          end
          result
        end

        def update_uris(app)
          return unless app.staged?
          message = dea_update_message(app)
          dea_publish_update(message)
        end

        def find_stats(app)
          search_options = {
              include_stats: true,
              states: [:RUNNING],
              version: app.version,
          }

          running_instances = find_instances(app, search_options)

          stats = {} # map of instance index to stats.
          running_instances.each do |instance|
            index = instance['index']
            if index >= 0 && index < app.instances
              stats[index] = {
                  state: instance['state'],
                  stats: instance['stats'],
              }
            end
          end

          # we may not have received responses from all instances.
          app.instances.times do |index|
            unless stats[index]
              stats[index] = {
                  state: 'DOWN',
                  since: Time.now.utc.to_i,
              }
            end
          end

          stats
        end

        def send_start(dea, message)
          dea_id = dea.dea_id

          if dea.url && enabled?
            url = dea.url
            logger.debug "sending 'dea.start' for dea_id: #{dea_id} to #{url} with '#{message}'"
            connection = @http_client.post_async("#{url}/v1/apps", header: { 'Content-Type' => 'application/json' }, body: MultiJson.dump(message))
            return lambda do
              begin
                conn = connection.pop
                return conn.status
              rescue => e
                logger.warn 'start failed', dea_id: dea_id, url: url, error: e.to_s
              end
            end
          end

          subject = "dea.#{dea_id}.start"
          logger.debug "sending 'dea.start'", dea_id: dea_id, subject: subject
          message_bus.publish(subject, message)

          nil
        end

        private

        def health_manager_client
          CloudController::DependencyLocator.instance.health_manager_client
        end

        # @return [FileUriResult]
        def get_file_uri(app, path, options)
          if app.stopped?
            msg = "Request failed for app: #{app.name} path: #{path || '/'} "
            msg << 'as the app is in stopped state.'

            raise ApiError.new_from_details('FileError', msg)
          end

          search_options = {
              states: [:STARTING, :RUNNING, :CRASHED],
              path: path,
          }.merge(options)

          if (instance_found = find_specific_instance(app, search_options))
            result = FileUriResult.new
            if instance_found['file_uri_v2']
              result.file_uri_v2 = instance_found['file_uri_v2']
            end

            uri_v1 = [instance_found['file_uri'], instance_found['staged'], '/', path].join('')
            result.file_uri_v1 = uri_v1
            result.credentials = instance_found['credentials']

            return result
          end

          nil
        end

        def dea_update_message(app)
          {
              droplet: app.guid,
              uris: app.uris,
              version: app.version,
          }
        end

        def dea_publish_update(args)
          logger.debug "sending 'dea.update' with '#{args}'"
          message_bus.publish('dea.update', args)
        end

        def dea_request_find_droplet(args, opts={})
          logger.debug "sending dea.find.droplet with args: '#{args}' and opts: '#{opts}'"
          message_bus.synchronous_request('dea.find.droplet', args, opts)
        end

        def scrub_sensitive_fields(message)
          scrubbed_message = message.dup
          scrubbed_message.delete(:services)
          scrubbed_message.delete(:executableUri)
          scrubbed_message.delete(:env)
          scrubbed_message
        end

        def logger
          @logger ||= Steno.logger('cc.dea.client')
        end
      end
    end
  end
end
