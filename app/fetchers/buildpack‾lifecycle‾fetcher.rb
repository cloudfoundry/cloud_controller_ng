module VCAP::CloudController
  class BuildpackLifecycleFetcher
    class << self
      def fetch(buildpack_names, stack_name)
        {
          stack: Stack.find(name: stack_name),
          buildpack_infos: ordered_buildpacks(buildpack_names, stack_name),
        }
      end

      private

      def ordered_buildpacks(buildpack_names, stack_name)
        buildpacks_with_stacks, buildpacks_without_stacks = Buildpack.list_admin_buildpacks(stack_name).partition(&:stack)

        buildpack_names.map do |buildpack_name|
          buildpack_record = buildpacks_with_stacks.find { |b| b.name == buildpack_name } || buildpacks_without_stacks.find { |b| b.name == buildpack_name }
          BuildpackInfo.new(buildpack_name, buildpack_record)
        end
      end
    end
  end
end
