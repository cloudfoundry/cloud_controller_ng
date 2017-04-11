module VCAP::CloudController
  module Jobs
    module Runtime
      class BuildpackDelete < VCAP::CloudController::Jobs::CCJob
        def initialize(guid:, timeout:)
          @guid = guid
          @timeout = timeout
        end

        def perform
          buildpack = Jobs::Runtime::ModelDeletion.new(Buildpack, @guid).perform

          BuildpackBitsDelete.delete_when_safe(buildpack.key, @timeout) if buildpack
        end
      end
    end
  end
end
