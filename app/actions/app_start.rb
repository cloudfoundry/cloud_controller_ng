module VCAP::CloudController
  class AppStart
    class DropletNotFound < StandardError; end

    def start(app)
      droplet = DropletModel.find(guid: app.desired_droplet_guid)
      raise DropletNotFound if droplet.nil?

      package = PackageModel.find(guid: droplet.package_guid)
      package_hash = package.nil? ? 'unknown' : package.package_hash

      app.db.transaction do
        app.update(desired_state: 'STARTED')

        app.processes.each do |process|
          process.update({
            state: 'STARTED',
            package_hash: package_hash,
            package_state: 'STAGED',
            package_pending_since: nil,
            environment_json: app.environment_variables
          })
        end
      end
    end
  end
end
