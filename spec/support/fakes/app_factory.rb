module VCAP
  module CloudController
    class AppFactory
      def self.make(opts={})
        droplet_hash = opts[:droplet_hash]
        if !opts.has_key?(:droplet_hash)
          droplet_hash = Sham.guid
        end
        opts.delete(:droplet_hash)

        app = VCAP::CloudController::App.make(opts)
        if droplet_hash
          app.package_hash = Sham.guid unless app.package_hash
          app.add_new_droplet(droplet_hash)
          app.save
        end
        # Return a fresh object without previous changes
        return App.find(id: app.id)
      end
    end
  end
end
