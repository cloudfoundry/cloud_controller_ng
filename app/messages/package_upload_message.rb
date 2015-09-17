require 'messages/base_message'

module VCAP::CloudController
  class PackageUploadMessage < BaseMessage
    ALLOWED_KEYS = [:bits_path, :bits_name]

    attr_accessor(*ALLOWED_KEYS)

    validates_with NoAdditionalKeysValidator

    validates :bits_path, presence: { presence: true, message: 'An application zip file must be uploaded' }

    def self.create_from_params(params)
      PackageUploadMessage.new(params.symbolize_keys)
    end

    private

    def allowed_keys
      ALLOWED_KEYS
    end
  end
end
