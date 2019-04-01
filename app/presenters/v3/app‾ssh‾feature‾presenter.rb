require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class AppSshFeaturePresenter < BasePresenter
    def to_hash
      {
        name:        'ssh',
        description: 'Enable SSHing into the app.',
        enabled:     app.enable_ssh,
      }
    end

    private

    def app
      @resource
    end
  end
end
