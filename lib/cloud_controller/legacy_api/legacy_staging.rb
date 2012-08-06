# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController
  class LegacyStaging < LegacyApiBase
    include VCAP::CloudController::Errors

    def download_app(id)
      app = Models::App.find(:guid => id)
      raise AppNotFound.new(id) if app.nil?

      package_path = AppPackage.package_path(id)
      logger.debug "id: #{id} package_path: #{package_path}"

      unless File.exist?(package_path)
        logger.error "could not find package for #{id}"
        raise AppPackageNotFound.new(id)
      end

      # TODO: enable nginx
      # response.headers['X-Accel-Redirect'] = '/droplets/' + File.basename(path)
      # render :nothing => true, :status => 200
      send_file package_path
    end

    get "/staging/app/:id", :download_app
  end
end
