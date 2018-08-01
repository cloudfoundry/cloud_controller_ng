module VCAP::CloudController
  module Diego
    class TaskCompletionCallbackGenerator
      def initialize(config=Config.config)
        @config = config
      end

      def generate(task)
        auth      = "#{@config[:internal_api][:auth_user]}:#{@config[:internal_api][:auth_password]}"
        host_port = "#{@config[:internal_service_hostname]}:#{@config[:external_port]}"
        path      = "/internal/v3/tasks/#{task.guid}/completed"
        "http://#{auth}@#{host_port}#{path}"
      end
    end
  end
end
