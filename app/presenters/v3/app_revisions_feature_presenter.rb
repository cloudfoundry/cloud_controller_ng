require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class AppRevisionsFeaturePresenter < BasePresenter
    def to_hash
      {
        name: VCAP::CloudController::AppFeatures::REVISIONS_FEATURE,
        description: 'Enable versioning of an application',
        enabled: app.revisions_enabled
      }
    end

    private

    def app
      @resource
    end
  end
end
