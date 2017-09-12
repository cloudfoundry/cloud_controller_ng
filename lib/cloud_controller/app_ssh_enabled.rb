module VCAP::CloudController
  class AppSshEnabled
    def initialize(app)
      @app = app
    end

    def enabled?
      Config.config.get(:allow_app_ssh_access) && app.space.allow_ssh && app.enable_ssh
    end

    private

    attr_reader :app
  end
end
