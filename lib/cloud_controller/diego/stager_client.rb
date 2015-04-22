require 'cloud_controller/diego/staging_guid'

module VCAP::CloudController
  module Diego
    REQUEST_HEADERS = { 'Content-Type' => 'application/json' }

    class StagerClient
      def initialize(config)
        @url = URI(config[:diego_stager_url]) if config[:diego_stager_url]
      end

      def stage(staging_guid, staging_message)
        if @url.nil?
          raise Errors::ApiError.new_from_details('StagerUnavailable', 'invalid config')
        end

        logger.info('stage.request', staging_guid: staging_guid)

        path = "/v1/staging/#{staging_guid}"

        begin
          tries ||= 3
          response = http_client.put(path, staging_message, REQUEST_HEADERS)
        rescue Errno::ECONNREFUSED => e
          retry unless (tries -= 1).zero?
          raise Errors::ApiError.new_from_details('StagerUnavailable', e)
        end

        logger.info('stage.response', staging_guid: staging_guid, response_code: response.code)

        if response.code != '202'
          raise Errors::ApiError.new_from_details('StagerError', "staging failed: #{error_message(response)}")
        end

        nil
      end

      def stop_staging(staging_guid)
        if @url.nil?
          raise Errors::ApiError.new_from_details('StagerUnavailable', 'invalid config')
        end

        logger.info('stop.staging.request', staging_guid: staging_guid)

        path = "/v1/staging/#{staging_guid}"

        begin
          tries ||= 3
          response = http_client.delete(path, REQUEST_HEADERS)
        rescue Errno::ECONNREFUSED => e
          retry unless (tries -= 1).zero?
          raise Errors::ApiError.new_from_details('StagerUnavailable', e)
        end

        logger.info('stop.staging.response', staging_guid: staging_guid, response_code: response.code)

        case response.code
        when '202', '404'
          # success
        else
          raise Errors::ApiError.new_from_details('StagerError', "stop failed: #{response.code}")
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
        @logger ||= Steno.logger('cc.stager.client')
      end

      def error_message(response)
        JSON.parse(response.body)['error']['message'] || response.code
      rescue JSON::ParserError, NoMethodError
        response.code
      end
    end
  end
end
