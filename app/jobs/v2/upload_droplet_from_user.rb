module VCAP::CloudController
  module Jobs
    module V2
      class UploadDropletFromUser
        attr_reader :max_attempts

        def initialize(local_path, droplet_guid)
          @local_path   = local_path
          @droplet_guid = droplet_guid
          @max_attempts = 3
        end

        def perform
          Jobs::V3::DropletUpload.new(@local_path, @droplet_guid, skip_state_transition: false).perform

          if (droplet = DropletModel.where(guid: @droplet_guid).first)
            droplet.app.update(droplet: droplet) if droplet.staged?
          end
        end
      end
    end
  end
end
