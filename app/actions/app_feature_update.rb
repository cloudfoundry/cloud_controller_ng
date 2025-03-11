module VCAP::CloudController
  class AppFeatureUpdate
    def self.update(feature_name, app, message)
      case feature_name
      when AppFeaturesController::SSH_FEATURE
        app.update(enable_ssh: message.enabled)
      when AppFeaturesController::REVISIONS_FEATURE
        app.update(revisions_enabled: message.enabled)
      when AppFeaturesController::SERVICE_BINDING_K8S_FEATURE
        app.update(service_binding_k8s_enabled: message.enabled)
      when AppFeaturesController::FILE_BASED_VCAP_SERVICES_FEATURE
        app.update(file_based_vcap_services_enabled: message.enabled)
      end
    end
  end
end
