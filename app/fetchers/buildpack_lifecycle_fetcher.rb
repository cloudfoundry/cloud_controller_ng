require 'cloud_controller/diego/lifecycles/lifecycles'

module VCAP::CloudController
  class BuildpackLifecycleFetcher
    class << self
      def fetch(buildpack_names, stack_name, lifecycle=Config.config.get(:default_app_lifecycle))
        return { stack: nil, buildpack_infos: custom_stack_buildpacks(buildpack_names, lifecycle) } if UriUtils.is_custom_stack_uri?(stack_name)

        {
          stack: Stack.find(name: stack_name),
          buildpack_infos: ordered_buildpacks(buildpack_names, stack_name, lifecycle)
        }
      end

      private

      def custom_stack_buildpacks(buildpack_names, lifecycle)
        buildpacks_without_stacks = Buildpack.list_admin_buildpacks(nil, lifecycle).select { |buildpack| buildpack.stack.nil? }

        Array(buildpack_names).map do |buildpack_name|
          buildpack_record = buildpacks_without_stacks.find { |buildpack| buildpack.name == buildpack_name }
          BuildpackInfo.new(buildpack_name, buildpack_record)
        end
      end

      def ordered_buildpacks(buildpack_names, stack_name, lifecycle)
        buildpacks_with_stacks, buildpacks_without_stacks = Buildpack.list_admin_buildpacks(stack_name, lifecycle).partition(&:stack)

        buildpack_names.map do |buildpack_name|
          buildpack_record = buildpacks_with_stacks.find { |b| b.name == buildpack_name } || buildpacks_without_stacks.find { |b| b.name == buildpack_name }
          BuildpackInfo.new(buildpack_name, buildpack_record)
        end
      end
    end
  end
end
