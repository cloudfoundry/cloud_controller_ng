module VCAP::CloudController
  module Jobs
    module V3
      class BuildpackCacheUpload
        attr_reader :max_attempts

        def initialize(local_path:, app_guid:, stack_name:)
          @local_path   = local_path
          @app_guid     = app_guid
          @stack_name   = stack_name
          @max_attempts = 3
        end

        def perform
          app = AppModel.find(guid: @app_guid)

          if app
            sha256_digest = Digester.new(algorithm: Digest::SHA256).digest_path(@local_path)
            blobstore_key = Presenters::V3::CacheKeyPresenter.cache_key(guid: @app_guid, stack_name: @stack_name)

            blobstore.cp_to_blobstore(@local_path, blobstore_key)

            app.update(buildpack_cache_sha256_checksum: sha256_digest)
          end

          FileUtils.rm_f(@local_path)
        end

        def error(job, _)
          if !File.exist?(@local_path)
            @max_attempts = 1
          end

          if job.attempts >= max_attempts - 1
            FileUtils.rm_f(@local_path)
          end
        end

        def job_name_in_configuration
          :buildpack_cache_upload
        end

        def blobstore
          @blobstore ||= CloudController::DependencyLocator.instance.buildpack_cache_blobstore
        end
      end
    end
  end
end
