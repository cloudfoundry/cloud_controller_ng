module VCAP::CloudController
  class AppFeatures
    SSH_FEATURE = 'ssh'.freeze
    REVISIONS_FEATURE = 'revisions'.freeze
    SERVICE_BINDING_K8S_FEATURE = 'service-binding-k8s'.freeze
    FILE_BASED_VCAP_SERVICES_FEATURE = 'file-based-vcap-services'.freeze

    DATABASE_COLUMNS_MAPPING = {
      SSH_FEATURE => :enable_ssh,
      REVISIONS_FEATURE => :revisions_enabled,
      SERVICE_BINDING_K8S_FEATURE => :service_binding_k8s_enabled,
      FILE_BASED_VCAP_SERVICES_FEATURE => :file_based_vcap_services_enabled
    }.freeze

    def self.all_features
      [SSH_FEATURE, REVISIONS_FEATURE, SERVICE_BINDING_K8S_FEATURE, FILE_BASED_VCAP_SERVICES_FEATURE]
    end
  end
end
