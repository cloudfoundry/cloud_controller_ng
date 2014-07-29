require 'set'

module VCAP::CloudController
  module Dea
    module HM9000
      class Client
        APP_STATE_BULK_MAX_APPS = 50

        def initialize(message_bus, config)
          @message_bus = message_bus
          @config = config
        end

        def healthy_instances(app)
          healthy_instance_count(app, app_state_request(app))
        end

        def healthy_instances_bulk(apps)
          return {} if apps.nil? || apps.empty?

          response = app_state_bulk_request(apps)
          apps.each_with_object({}) do |app, result|
            result[app.guid] = healthy_instance_count(app, response[app.guid])
          end
        end

        def find_crashes(app)
          response = app_state_request(app)
          return [] unless response

          response["instance_heartbeats"].each_with_object([]) do |instance, result|
            if instance["state"] == "CRASHED"
              result << {"instance" => instance["instance"], "since" => instance["state_timestamp"]}
            end
          end
        end

        def find_flapping_indices(app)
          response = app_state_request(app)
          return [] unless response

          response["crash_counts"].each_with_object([]) do |crash_count, result|
            if crash_count["crash_count"] >= @config[:flapping_crash_count_threshold]
              result << {"index" => crash_count["instance_index"], "since" => crash_count["created_at"]}
            end
          end
        end

        private

        def app_message(app)
          { droplet: app.guid, version: app.version }
        end

        def app_state_request(app)
          make_request("app.state", app_message(app))
        end

        def app_state_bulk_request(apps)
          apps.each_slice(APP_STATE_BULK_MAX_APPS).reduce({}) do |result, slice|
            result.merge(make_request("app.state.bulk", slice.map { |app| app_message(app) }) || {})
          end
        end

        def make_request(subject, message, timeout=2)
          logger.info("requesting #{subject}", message: message)
          responses = @message_bus.synchronous_request(subject, message, { timeout: timeout })
          logger.info("received #{subject} response", { message: message, responses: responses })
          return if responses.empty?

          response = responses.first
          return if response.empty?

          response
        end

        def healthy_instance_count(app, response)
          if response.nil? || response["instance_heartbeats"].nil?
            return -1
          end

          response["instance_heartbeats"].each_with_object(Set.new) do |heartbeats, result|
            if heartbeats["index"] < app.instances && (heartbeats["state"] == "RUNNING" || heartbeats["state"] == "STARTING")
              result.add(heartbeats["index"])
            end
          end.length
        end

        def logger
          @logger ||= Steno.logger("cc.healthmanager.client")
        end
      end
    end
  end
end
