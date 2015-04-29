require 'messages/base_message'

module VCAP::CloudController
  class PackageUploadMessage < BaseMessage
    attr_accessor :bits_path, :bits_name

    def allowed_keys
      [:bits_path, :bits_name]
    end

    validates_with NoAdditionalKeysValidator

    validates :bits_path, presence: { presence: true, message: 'An application zip file must be uploaded' }

    def self.create_from_params(params)
      PackageUploadMessage.new(params.symbolize_keys)
    end
  end
end
