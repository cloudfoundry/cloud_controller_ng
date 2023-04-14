module VCAP::CloudController
  class DropletUpdate
    class Error < ::StandardError; end
    class InvalidDroplet < StandardError; end

    def update(droplet, message)
      droplet.db.transaction do
        droplet.lock!

        if message.requested?(:image)
          raise InvalidDroplet.new('Droplet image can only be updated on staged droplets') unless droplet.staged?
          raise InvalidDroplet.new('Images can only be updated for docker droplets') unless droplet.docker?

          droplet.docker_receipt_image = message.image
        end

        LabelsUpdate.update(droplet, message.labels, DropletLabelModel)
        AnnotationsUpdate.update(droplet, message.annotations, DropletAnnotationModel)
        droplet.save
      end

      droplet
    rescue Sequel::ValidationFailed => e
      validation_error!(e)
    end
  end
end
