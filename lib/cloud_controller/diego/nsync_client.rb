require 'cloud_controller/diego/process_guid'

module VCAP::CloudController
  module Diego
    class NsyncClient
      def initialize(config)
        @url = URI(config[:diego_nsync_url]) if config[:diego_nsync_url]
      end

      def desire_app(process_guid, desire_message)
        if @url.nil?
          raise Errors::ApiError.new_from_details('RunnerUnavailable', 'invalid config')
        end

        logger.info('desire.app.request', process_guid: process_guid)

        path = "/v1/apps/#{process_guid}"

        begin
          tries ||= 3
          response = http_client.put(path, desire_message, REQUEST_HEADERS)
        rescue Errno::ECONNREFUSED => e
          retry unless (tries -= 1).zero?
          raise Errors::ApiError.new_from_details('RunnerUnavailable', e)
        end

        logger.info('desire.app.response', process_guid: process_guid, response_code: response.code)

        if response.code != '202'
          raise Errors::ApiError.new_from_details('RunnerError', "desire app failed: #{response.code}")
        end

        nil
      end

      def stop_app(process_guid)
        if @url.nil?
          raise Errors::ApiError.new_from_details('RunnerUnavailable', 'invalid config')
        end

        logger.info('stop.app.request', process_guid: process_guid)

        path = "/v1/apps/#{process_guid}"

        begin
          tries ||= 3
          response = http_client.delete(path, REQUEST_HEADERS)
        rescue Errno::ECONNREFUSED => e
          retry unless (tries -= 1).zero?
          raise Errors::ApiError.new_from_details('RunnerUnavailable', e)
        end

        logger.info('stop.app.response', process_guid: process_guid, response_code: response.code)

        case response.code
        when '202', '404'
          # success
        else
          raise Errors::ApiError.new_from_details('RunnerError', "stop app failed: #{response.code}")
        end

        nil
      end

      def stop_index(process_guid, index)
        if @url.nil?
          raise Errors::ApiError.new_from_details('RunnerUnavailable', 'invalid config')
        end

        logger.info('stop.index.request', process_guid: process_guid, index: index)

        path = "/v1/apps/#{process_guid}/index/#{index}"

        begin
          tries ||= 3
          response = http_client.delete(path, REQUEST_HEADERS)
        rescue Errno::ECONNREFUSED => e
          retry unless (tries -= 1).zero?
          raise Errors::ApiError.new_from_details('RunnerUnavailable', e)
        end

        logger.info('stop.index.response', process_guid: process_guid, index: index, response_code: response.code)

        case response.code
        when '202', '404'
          # success
        else
          raise Errors::ApiError.new_from_details('RunnerError', "stop index failed: #{response.code}")
        end

        nil
      end

      private

      def http_client
        http_client = Net::HTTP.new(@url.host, @url.port)
        http_client.read_timeout = 10
        http_client.open_timeout = 10
        http_client
      end

      def logger
        @logger ||= Steno.logger('cc.nsync.listener.client')
      end
    end
  end
end
