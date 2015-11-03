require 'messages/nested_message_validator'

module VCAP::CloudController
  class DockerDataValidator < NestedMessageValidator
    CREDENTIALS_KEYS = [:user, :password, :email, :login_server]

    def self.credentialed?
      '!credentials.nil?'
    end

    validates :image, string: true, presence: { message: 'required' }
    validates :store_image, inclusion: { in: [true, false], message: 'must be a boolean', allow_nil: true }
    validates :credentials_user, string: true, presence: { message: 'required' }, if: credentialed?
    validates :credentials_password, string: true, presence: { message: 'required' }, if: credentialed?
    validates :credentials_email, string: true, presence: { message: 'required' }, if: credentialed?
    validates :credentials_login_server, string: true, presence: { message: 'required' }, if: credentialed?

    delegate :type, :data, to: :record

    CREDENTIALS_KEYS.each do |credential|
      define_method "credentials_#{credential}" do
        credentials[credential.to_sym] if credentials
      end
    end

    def image
      record.data.fetch(:image, nil)
    end

    def credentials
      record.data.fetch(:credentials, nil)
    end

    def store_image
      record.data.fetch(:store_image, nil)
    end

    def should_validate?
      record.type == 'docker' && !data.nil?
    end

    def error_key
      :data
    end
  end
end
