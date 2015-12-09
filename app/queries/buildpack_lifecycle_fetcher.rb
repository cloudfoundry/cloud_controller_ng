module VCAP::CloudController
  class BuildpackLifecycleFetcher
    def fetch(buildpack_name, stack_name)
      {
        stack: Stack.find(name: stack_name),
        buildpack: Buildpack.find(name: buildpack_name)
      }
    end
  end
end
