require 'messages/metadata_base_message'

module VCAP::CloudController
  class DeploymentCreateMessage < MetadataBaseMessage
    register_allowed_keys [
      :relationships,
      :revision,
      :droplet,
    ]

    def app_guid
      relationships&.dig(:app, :data, :guid)
    end

    def revision_guid
      revision&.dig(:guid)
    end

    def droplet_guid
      droplet&.dig(:guid)
    end
  end
end
