module VCAP::CloudController
  module Jobs
    module Runtime
      class AppBitsCopier < VCAP::CloudController::Jobs::CCJob
        def initialize(src_app, dest_app, app_event_repo, user, email)
          @user           = user
          @email          = email
          @src_app        = src_app
          @dest_app       = dest_app
          @app_event_repo = app_event_repo
        end

        def perform
          logger = Steno.logger('cc.background')
          logger.info("Copying the app bits from app '#{@src_app.guid}' to app '#{@dest_app.guid}'")

          package_blobstore = CloudController::DependencyLocator.instance.package_blobstore
          package_blobstore.cp_file_between_keys(@src_app.guid, @dest_app.guid)
          @dest_app.package_hash = @src_app.package_hash
          @dest_app.save
          @app_event_repo.record_src_copy_bits(@dest_app, @src_app, @user.guid, @email)
          @app_event_repo.record_dest_copy_bits(@dest_app, @src_app, @user.guid, @email)
        end

        def job_name_in_configuration
          :app_bits_copier
        end

        def max_attempts
          1
        end
      end
    end
  end
end
