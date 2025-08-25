require 'cloud_controller/diego/lifecycles/lifecycles'

module VCAP::CloudController
  class BuildpackLifecycleFetcher
    class << self
      def fetch(buildpack_names, stack_name, lifecycle=Config.config.get(:default_app_lifecycle))
        # Try to find the stack in the database first
        stack = Stack.find(name: stack_name) if stack_name.is_a?(String)

        # If not found and it looks like a custom stack URL, use it as-is (normalized)
        if stack.nil? && stack_name.is_a?(String) && is_custom_stack?(stack_name)
          stack = normalize_stack_url(stack_name)
        end

        {
          stack: stack,
          buildpack_infos: ordered_buildpacks(buildpack_names, stack_name, lifecycle)
        }
      end

      private

      def ordered_buildpacks(buildpack_names, stack_name, lifecycle)
        buildpacks_with_stacks, buildpacks_without_stacks = Buildpack.list_admin_buildpacks(stack_name, lifecycle).partition(&:stack)

        buildpack_names.map do |buildpack_name|
          buildpack_record = buildpacks_with_stacks.find { |b| b.name == buildpack_name } || buildpacks_without_stacks.find { |b| b.name == buildpack_name }
          BuildpackInfo.new(buildpack_name, buildpack_record)
        end
      end

      def is_custom_stack?(stack_name)
        # Check for various container registry URL formats
        return true if stack_name.include?('docker://')
        return true if stack_name.match?(%r{^https?://})  # Any https/http URL
        return true if stack_name.include?('.')  # Any string with a dot (likely a registry)
        false
      end

      def normalize_stack_url(stack_url)
        return stack_url if stack_url.start_with?('docker://')
        return stack_url.sub(/^https?:\/\//, 'docker://') if stack_url.match?(%r{^https?://})
        return "docker://#{stack_url}" if stack_url.match?(%r{^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/.+})
        stack_url
      end
    end
  end
end
