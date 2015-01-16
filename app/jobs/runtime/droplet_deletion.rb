module VCAP::CloudController
  module Jobs
    module Runtime
      class DropletDeletion < VCAP::CloudController::Jobs::CCJob
        attr_accessor :new_droplet_key, :old_droplet_key

        def initialize(new_droplet_key, old_droplet_key)
          @new_droplet_key = new_droplet_key
          @old_droplet_key = old_droplet_key
        end

        def perform
          logger = Steno.logger('cc.background')
          logger.info("Deleting droplet '#{new_droplet_key}' (and '#{old_droplet_key}') from droplet blobstore")
          blobstore = CloudController::DependencyLocator.instance.droplet_blobstore
          blobstore.delete(new_droplet_key)
          begin
            blobstore.delete(old_droplet_key)
          rescue Errno::EISDIR
            # The new droplets are with a path which is under the old droplet path
            # This means that sometimes, if there are multiple versions of a droplet,
            # the directory will still exist after we delete the droplet.
            # We don't care for now, but we don't want the errors.
          end
        end

        def job_name_in_configuration
          :droplet_deletion
        end

        def max_attempts
          3
        end
      end
    end
  end
end
