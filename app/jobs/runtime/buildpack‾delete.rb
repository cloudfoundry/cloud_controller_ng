module VCAP::CloudController
  module Jobs
    module Runtime
      class BuildpackDelete < VCAP::CloudController::Jobs::CCJob
        def initialize(guid:, timeout:)
          @guid = guid
          @timeout = timeout
        end

        def perform
          buildpack = nil
          buildpacks_lock = Locking[name: 'buildpacks']
          buildpacks_lock.db.transaction do
            buildpacks_lock.lock!
            buildpack = Jobs::Runtime::ModelDeletion.new(Buildpack, @guid).perform
          end
          BuildpackBitsDelete.delete_when_safe(buildpack.key, @timeout) if buildpack
        end
      end
    end
  end
end
