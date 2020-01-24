require 'messages/metadata_base_message'

module VCAP::CloudController
  class DeploymentCreateMessage < MetadataBaseMessage
    register_allowed_keys [
      :relationships,
      :droplet,
      :revision,
      :strategy,
    ]

    validates_with NoAdditionalKeysValidator
    validates :strategy,
      inclusion: { in: %w(rolling), message: "'%<value>s' is not a supported deployment strategy" },
      allow_nil: true
    validate :mutually_exclusive_droplet_sources

    def app_guid
      relationships&.dig(:app, :data, :guid)
    end

    def droplet_guid
      droplet&.dig(:guid)
    end

    def revision_guid
      revision&.dig(:guid)
    end

    private

    def mutually_exclusive_droplet_sources
      if revision.present? && droplet.present?
        errors.add(:droplet, "Cannot set both fields 'droplet' and 'revision'")
      end
    end
  end
end
