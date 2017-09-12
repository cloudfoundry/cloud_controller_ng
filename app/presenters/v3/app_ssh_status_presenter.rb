require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class AppSshStatusPresenter
    def initialize(app, space, globally_enabled)
      @app = app
      @space = space
      @globally_enabled = globally_enabled
    end

    def to_hash
      {
        enabled: enabled?,
        reason: reason
      }
    end

    private

    attr_reader :app, :space, :globally_enabled

    def enabled?
      globally_enabled && space.allow_ssh && app.enable_ssh
    end

    def reason
      if !globally_enabled
        'Disabled globally'
      elsif !space.allow_ssh
        "Disabled for space #{space.name}"
      elsif !app.enable_ssh
        'Disabled for app'
      else
        ''
      end
    end
  end
end
