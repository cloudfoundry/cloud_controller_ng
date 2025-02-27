require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class AppFileBasedVcapServicesFeaturePresenter < BasePresenter
    def to_hash
      {
        name: 'file-based-vcap-services',
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
