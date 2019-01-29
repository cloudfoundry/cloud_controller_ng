require 'messages/app_manifest_message'
require 'messages/validators'

module VCAP::CloudController
  class NamedAppManifestMessage < AppManifestMessage
    register_allowed_keys [:name]

    def self.create_from_yml(parsed_yaml)
      self.new(parsed_yaml, underscore_keys(parsed_yaml.deep_symbolize_keys))
    end

    validates :name, string: true, allow_nil: false
  end
end
