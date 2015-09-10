module VCAP::CloudController
  class DropletDelete
    def delete(droplets)
      droplets = [droplets] unless droplets.is_a?(Array)

      droplets.each do |droplet|
        if droplet.blobstore_key
          blobstore_delete = Jobs::Runtime::BlobstoreDelete.new(droplet.blobstore_key, :droplet_blobstore, nil)
          Jobs::Enqueuer.new(blobstore_delete, queue: 'cc-generic').enqueue
        end

        droplet.destroy
      end
    end
  end
end
