module VCAP::CloudController
  module Jobs
    module Runtime
      class DropletUpload < VCAP::CloudController::Jobs::CCJob
        attr_reader :local_path, :app_id

        def initialize(local_path, app_id, config=Config.config)
          @local_path = local_path
          @app_id = app_id
          @droplets_storage_count = config[:droplets][:max_staged_droplets_stored] || 2
        end

        def perform
          logger = Steno.logger('cc.background')
          logger.info("Uploading droplet for '#{app_id}' to droplet blobstore")

          app = VCAP::CloudController::App[id: app_id]

          if app
            blobstore = CloudController::DependencyLocator.instance.droplet_blobstore
            CloudController::DropletUploader.new(app, blobstore).upload(local_path, @droplets_storage_count)
          end

          FileUtils.rm_f(local_path)
        end

        def job_name_in_configuration
          :droplet_upload
        end

        def max_attempts
          1
        end

        def error(job, _)
          if job.attempts >= max_attempts - 1
            FileUtils.rm_f(local_path)
          end
        end
      end
    end
  end
end
