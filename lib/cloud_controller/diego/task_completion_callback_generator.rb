module VCAP::CloudController
  module Diego
    class TaskCompletionCallbackGenerator
      def initialize(config=Config.config)
        @config = config
      end

      def generate(task)
        schema = 'https'
        auth = ''
        host = @config[:internal_service_hostname]
        port = @config[:tls_port]
        api_version = 'v4'

        unless @config.fetch(:diego, {})[:temporary_local_sync]
          schema = 'http'
          auth = "#{@config[:internal_api][:auth_user]}:#{@config[:internal_api][:auth_password]}@"
          port = @config[:external_port]
          api_version = 'v3'
        end

        path = "/internal/#{api_version}/tasks/#{task.guid}/completed"

        "#{schema}://#{auth}#{host}:#{port}#{path}"
      end
    end
  end
end
