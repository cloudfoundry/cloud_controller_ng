require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class AppFileBasedVcapServicesFeaturePresenter < BasePresenter
    def to_hash
      {
        name: AppFeaturesController::FILE_BASED_VCAP_SERVICES_FEATURE,
        description: 'Enable file-based VCAP service bindings for the app',
        enabled: app.file_based_vcap_services_enabled
      }
    end

    private

    def app
      @resource
    end
  end
end
