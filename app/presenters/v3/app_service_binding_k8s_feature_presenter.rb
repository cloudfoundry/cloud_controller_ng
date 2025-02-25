require 'presenters/v3/base_presenter'

module VCAP::CloudController::Presenters::V3
  class AppServiceBindingK8sFeaturePresenter < BasePresenter
    def to_hash
      {
        name: 'service-binding-k8s',
        description: 'Enable k8s service bindings for the app',
        enabled: app.service_binding_k8s_enabled
      }
    end

    private

    def app
      @resource
    end
  end
end
