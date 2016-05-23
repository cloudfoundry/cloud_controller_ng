module VCAP::CloudController
  class DropletCopy
    CLONED_ATTRIBUTES = [
      :buildpack_receipt_buildpack_guid,
      :detected_start_command,
      :salt,
      :process_types,
      :buildpack_receipt_buildpack,
      :buildpack_receipt_stack_name,
      :execution_metadata,
      :staging_memory_in_mb,
      :staging_disk_in_mb,
      :docker_receipt_image
    ].freeze

    def initialize(source_droplet)
      @source_droplet = source_droplet
    end

    def copy(destination_app, user_guid, user_email)
      new_droplet = DropletModel.new(state: DropletModel::PENDING_STATE, app_guid: destination_app.guid)

      # Needed to execute serializers and deserializers correctly on source and destination models
      CLONED_ATTRIBUTES.each do |attr|
        new_droplet.send("#{attr}=", @source_droplet.send(attr))
      end

      DropletModel.db.transaction do
        if @source_droplet.buildpack?
          new_droplet.save
          copy_buildpack_droplet(new_droplet)
        elsif @source_droplet.docker?
          new_droplet.state = @source_droplet.state
          new_droplet.save
        end

        Repositories::DropletEventRepository.record_create_by_copying(
          new_droplet.guid,
          @source_droplet.guid,
          user_guid,
          user_email,
          destination_app.guid,
          destination_app.name,
          destination_app.space_guid,
          destination_app.space.organization_guid
          )
      end
      new_droplet.reload
    end

    def copy_buildpack_droplet(new_droplet)
      BuildpackLifecycleDataModel.create(droplet_guid: new_droplet.guid,
                                         stack:                                         @source_droplet.buildpack_lifecycle_data.stack,
                                         buildpack:                                     @source_droplet.buildpack_lifecycle_data.buildpack)

      copy_job = Jobs::V3::DropletBitsCopier.new(@source_droplet.guid, new_droplet.guid)
      Jobs::Enqueuer.new(copy_job, queue: 'cc-generic').enqueue
    end
  end
end
