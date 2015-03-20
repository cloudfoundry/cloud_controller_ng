module VCAP::CloudController
  class AppUpdate
    class DropletNotFound < StandardError; end
    class InvalidApp < StandardError; end

    def self.update(app, message)
      app.db.transaction do
        app.lock!

        app.name = message['name'] unless message['name'].nil?

        if message['desired_droplet_guid']
          droplet = DropletModel.find(guid: message['desired_droplet_guid'])
          raise DropletNotFound if droplet.nil?
          raise DropletNotFound if droplet.app_guid != app.guid
          app.desired_droplet_guid = message['desired_droplet_guid']
        end

        app.save
      end

      app
    rescue Sequel::ValidationFailed => e
      raise InvalidApp.new(e.message)
    end
  end
end
