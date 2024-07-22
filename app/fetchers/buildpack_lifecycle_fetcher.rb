require 'cloud_controller/diego/lifecycles/lifecycles'

module VCAP::CloudController
  class BuildpackLifecycleFetcher
    class << self
      def fetch(buildpack_names, stack_name, lifecycle=VCAP::CloudController::Lifecycles::BUILDPACK)
        {
          stack: Stack.find(name: stack_name),
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
    end
  end
end
