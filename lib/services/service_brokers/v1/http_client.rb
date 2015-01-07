module VCAP::Services
  module ServiceBrokers::V1
    class HttpClient
      def initialize(attrs)
        @url = attrs.fetch(:url)
        @token = attrs.fetch(:auth_token)
        @broker_client_timeout = VCAP::CloudController::Config.config[:broker_client_timeout_seconds] || 60
      end

      def provision(plan_id, name, options={})
        body = options.merge(
          unique_id: plan_id,
          name: name
        ).to_json

        execute(:post, '/gateway/v1/configurations', body)
      end

      def bind(instance_id, app_id, label, email, binding_options)
        body = {
          service_id: instance_id,
          app_id: app_id,
          label: label,
          email: email,
          binding_options: binding_options
        }.to_json

        execute(:post, "/gateway/v1/configurations/#{instance_id}/handles", body)
      end

      def unbind(instance_id, binding_id, binding_options)
        body = {
          service_id: instance_id,
          handle_id: binding_id,
          binding_options: binding_options
        }.to_json

        execute(:delete, "/gateway/v1/configurations/#{instance_id}/handles/#{binding_id}", body)
      end

      def deprovision(instance_id)
        execute(:delete, "/gateway/v1/configurations/#{instance_id}")
      end

      private

      attr_reader :broker_client_timeout

      def execute(method, path, body=nil)
        endpoint = @url + path
        uri = URI(endpoint)
        req_class = method.to_s.capitalize

        request = Net::HTTP.const_get(req_class).new(uri.request_uri)
        request.body = body
        request.content_type = 'application/json'
        request['Accept'] = 'application/json'
        request[VCAP::Request::HEADER_NAME] = VCAP::Request.current_id
        request['X-VCAP-Service-Token'] = @token

        logger.debug "Sending #{req_class} to #{uri.request_uri}, BODY: #{request.body.inspect}, HEADERS: #{request.to_hash.inspect}"

        use_ssl = uri.scheme.to_s.downcase == 'https'
        response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: use_ssl) do |http|
          http.open_timeout = broker_client_timeout
          http.read_timeout = broker_client_timeout

          http.request(request)
        end

        logger.debug [
          "Response from request to #{uri.request_uri}:",
          "STATUS #{response.code.to_i},",
          "BODY: #{response.body.inspect},",
          "HEADERS: #{response.to_hash.inspect}"
        ].join(' ')

        case response
        when Net::HTTPSuccess
          if response.body.present?
            return MultiJson.load(response.body)
          end
        else
          begin
            hash = MultiJson.load(response.body)
          rescue MultiJson::ParseError
          end

          if hash.is_a?(Hash) && hash.key?('description')
            message = "Service broker error: #{hash['description']}"
          else
            message = "The service broker API returned an error from #{endpoint}: #{response.code} #{response.message}"
          end

          raise HttpResponseError.new(message, endpoint, method, response)
        end
      end

      def logger
        @logger ||= Steno.logger('cc.service_broker.v1.http_client')
      end
    end
  end
end
