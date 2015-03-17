module VCAP::CloudController
  class DropletDelete
    def delete(droplet_dataset)
      droplet_dataset.select(:"#{DropletModel.table_name}__guid", :droplet_hash).each do |droplet|
        blobstore_delete = Jobs::Runtime::BlobstoreDelete.new(droplet.blobstore_key, :droplet_blobstore, nil)
        Jobs::Enqueuer.new(blobstore_delete, queue: 'cc-generic').enqueue
      end
      droplet_dataset.destroy
    end
  end
end
