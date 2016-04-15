module VCAP::CloudController
  class DropletCopy
    CLONED_ATTRIBUTES = [
      :buildpack_receipt_buildpack_guid,
      :detected_start_command,
      :encrypted_environment_variables,
      :salt,
      :process_types,
      :buildpack_receipt_buildpack,
      :buildpack_receipt_stack_name,
      :execution_metadata,
      :memory_limit,
      :disk_limit,
      :docker_receipt_image
    ].freeze

    def copy(source_droplet, target_app_guid)
      droplet_attrs = source_droplet.values.slice(*CLONED_ATTRIBUTES)
      droplet_attrs[:state] = DropletModel::PENDING_STATE
      droplet_attrs[:app_guid] = target_app_guid
      new_droplet = DropletModel.new(droplet_attrs)

      DropletModel.db.transaction do
        new_droplet.save

        if source_droplet.buildpack?
          BuildpackLifecycleDataModel.create(droplet_guid: new_droplet.guid,
                                             stack: source_droplet.buildpack_lifecycle_data.stack,
                                             buildpack: source_droplet.buildpack_lifecycle_data.buildpack)

          copy_job = Jobs::V3::DropletBitsCopier.new(source_droplet.guid, new_droplet.guid)
          Jobs::Enqueuer.new(copy_job, queue: 'cc-generic').enqueue
        end
      end
      new_droplet.reload
    end
  end
end
