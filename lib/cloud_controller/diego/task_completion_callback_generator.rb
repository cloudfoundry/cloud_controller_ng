module VCAP::CloudController
  module Diego
    class TaskCompletionCallbackGenerator
      def initialize(config=Config.config)
        @config = config
      end

      def generate(task)
        host_port = "#{@config[:internal_service_hostname]}:#{@config[:tls_port]}"
        path      = "/internal/v4/tasks/#{task.guid}/completed"
        "https://#{host_port}#{path}"
      end
    end
  end
end
