require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class AppFileBasedServiceBindingsFeaturePresenter < BasePresenter
    def to_hash
      {
        name: 'file-based-service-bindings',
        description: 'Enable file-based service bindings for the app',
        enabled: app.file_based_service_bindings_enabled
      }
    end

    private

    def app
      @resource
    end
  end
end
