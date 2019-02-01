require 'messages/app_manifest_message'
require 'messages/validators'

module VCAP::CloudController
  class NamedAppManifestMessage < AppManifestMessage
    register_allowed_keys [:name]

    validates :name, presence: { message: 'Name must not be empty' }, string: true
  end
end
