module VCAP::CloudController
  module ServiceBroker::V1
    class HttpClient
      TIMEOUT = 60 # seconds

      def initialize(attrs)
        @url = attrs.fetch(:url)
        @token = attrs.fetch(:auth_token)
      end

      def provision(plan_id, name, options = {})
        body = options.merge(
          unique_id: plan_id,
          name: name
        ).to_json

        execute(:post, '/gateway/v1/configurations', body)
      end

      def bind(instance_id, label, email, binding_options)
        body = {
          service_id: instance_id,
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

      def execute(method, path, body = nil)
        endpoint = @url + path
        uri = URI(endpoint)
        req_class = method.to_s.capitalize

        request = Net::HTTP.const_get(req_class).new(uri.request_uri)
        request.body = body
        request.content_type = 'application/json'
        request['Accept'] = 'application/json'
        request[VCAP::Request::HEADER_NAME] = VCAP::Request.current_id
        request['X-VCAP-Service-Token'] = @token

        response = Net::HTTP.start(uri.hostname, uri.port) do |http|
          http.open_timeout = TIMEOUT
          http.read_timeout = TIMEOUT

          http.request(request)
        end

        case response
        when Net::HTTPSuccess
          if response.body.present?
            return Yajl::Parser.parse(response.body)
          end
        else
          raise HttpResponseError.new("#{response.code} error from broker", endpoint, method, response)
        end
      end
    end
  end
end
