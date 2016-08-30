module VCAP::CloudController
  class DropletCopy
    class InvalidCopyError < StandardError; end

    CLONED_ATTRIBUTES = [
      :buildpack_receipt_buildpack_guid,
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
      raise InvalidCopyError.new('source droplet is not staged') unless @source_droplet.staged?

      new_droplet = DropletModel.new(state: DropletModel::COPYING_STATE, app: destination_app)

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

      new_droplet
    end

    def copy_buildpack_droplet(new_droplet)
      new_droplet.buildpack_lifecycle_data = BuildpackLifecycleDataModel.new(
        stack:     @source_droplet.buildpack_lifecycle_data.stack,
        buildpack: @source_droplet.buildpack_lifecycle_data.buildpack
      )

      copy_job = Jobs::V3::DropletBitsCopier.new(@source_droplet.guid, new_droplet.guid)
      Jobs::Enqueuer.new(copy_job, queue: 'cc-generic').enqueue
    end
  end
end
