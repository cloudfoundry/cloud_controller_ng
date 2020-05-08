module VCAP::CloudController
  class DropletUpdate
    class Error < ::StandardError
    end

    def update(droplet, message)
      droplet.db.transaction do
        droplet.lock!
        LabelsUpdate.update(droplet, message.labels, DropletLabelModel)
        AnnotationsUpdate.update(droplet, message.annotations, DropletAnnotationModel)

        if message.image
          droplet.update(docker_receipt_image: message.image)
          update_crd(droplet, message.image)
        end
        conditional_bust(droplet, message.cache_id)

        droplet.save
      end

      droplet
    rescue Sequel::ValidationFailed => e
      validation_error!(e)
    end

    private

    def update_crd(droplet, image)
      crd = crd_client.patch_droplet(droplet.guid, {
        # metadata: {
        #   resourceVersion: droplet.cache_id,
        # },
        spec: {
          image: image,
        },
      }, 'default')

      puts "!!! message.image #{image} !!!"
      puts "!!! resourceVersion #{crd.metadata.resourceVersion} !!!"
      droplet.update(cache_id: crd.metadata.resourceVersion)
    end

    def conditional_bust(droplet, cache_id)
      return if cache_id == droplet.cache_id

      crd = crd_client.get_droplet(droplet.guid, 'default')

      droplet.update(
        cache_id: crd.resourceVersion,
        docker_receipt_image: crd.spec.image,
      )

      puts "!!! read rv #{crd.metadata.resourceVersion} !!!"
      puts "!!! image #{crd.spec.image} !!!"
    end

    def crd_client
      CloudController::DependencyLocator.instance.droplet_crd_client
    end
  end
end
