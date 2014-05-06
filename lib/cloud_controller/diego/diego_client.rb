module VCAP::CloudController
  class DiegoClient
    def initialize(message_bus, blobstore_url_generator)
      @message_bus = message_bus
      @blobstore_url_generator = blobstore_url_generator
    end

    def desire(app)
      droplet_uri = @blobstore_url_generator.droplet_download_url(app)
      message = {
          app_id: app.guid,
          app_version: app.version,
          droplet_uri: droplet_uri,
          start_command: app.command
      }
      @message_bus.publish("diego.desire.app", message)
    end
  end
end