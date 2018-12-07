module VCAP::CloudController
  class DropletUpdate
    class Error < ::StandardError
    end

    def update(droplet, message)
      droplet.db.transaction do
        droplet.lock!
        LabelsUpdate.update(droplet, message.labels, DropletLabelModel)
        droplet.save
      end

      droplet
    rescue Sequel::ValidationFailed => e
      validation_error!(e)
    end
  end
end
