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
          Jobs::V3::DropletUpload.new(@local_path, @droplet_guid).perform

          if (droplet = DropletModel.where(guid: @droplet_guid).eager(:app).all.first)
            droplet.db.transaction do
              droplet.update(state: DropletModel::STAGED_STATE)
              droplet.app.update(droplet: droplet)
            end
          end
        end
      end
    end
  end
end
