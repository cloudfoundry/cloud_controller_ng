require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class SpaceSshFeaturePresenter < BasePresenter
    def to_hash
      {
        name:        'ssh',
        description: 'Enable SSHing into apps in the space.',
        enabled:     space.allow_ssh,
      }
    end

    private

    def space
      @resource
    end
  end
end
