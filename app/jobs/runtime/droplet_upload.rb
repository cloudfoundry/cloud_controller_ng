module VCAP::CloudController
  module Jobs
    module Runtime
      class DropletUpload < VCAP::CloudController::Jobs::CCJob
        attr_reader :local_path, :app_id
        attr_reader :max_attempts

        def initialize(local_path, app_id)
          @local_path = local_path
          @app_id = app_id
          @max_attempts = 3
        end

        def perform
          logger = Steno.logger('cc.background')
          logger.info("Uploading droplet for '#{app_id}' to droplet blobstore")

          app = VCAP::CloudController::App[id: app_id]

          if app
            blobstore = CloudController::DependencyLocator.instance.droplet_blobstore
            CloudController::DropletUploader.new(app, blobstore).upload(local_path)
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
          # if !File.exist?(local_path)
          #   @max_attempts = 1
          # end

          if job.attempts >= max_attempts - 1
            FileUtils.rm_f(local_path)
          end
        end
      end
    end
  end
end
