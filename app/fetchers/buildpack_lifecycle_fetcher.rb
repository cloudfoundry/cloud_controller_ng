module VCAP::CloudController
  class BuildpackLifecycleFetcher
    class << self
      def fetch(buildpack_names, stack_name)
        {
          stack: Stack.find(name: stack_name),
          buildpack_infos: ordered_buildpacks(buildpack_names),
        }
      end

      private

      def ordered_buildpacks(buildpack_names)
        buildpacks = Buildpack.where(name: buildpack_names).all

        buildpack_names.map do |buildpack_name|
          buildpack_record = buildpacks.find { |b| b.name == buildpack_name }
          BuildpackInfo.new(buildpack_name, buildpack_record)
        end
      end
    end
  end
end
