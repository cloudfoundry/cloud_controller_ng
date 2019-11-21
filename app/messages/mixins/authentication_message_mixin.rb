require 'messages/basic_credentials_message'
require 'messages/authentication_message'
require 'presenters/helpers/censorship'

module VCAP::CloudController::AuthenticationMessageMixin
  def username
    HashUtils.dig(authentication, :credentials, :username)
  end

  def password
    HashUtils.dig(authentication, :credentials, :password)
  end

  def authentication_type
    HashUtils.dig(authentication, :type)
  end

  def audit_hash
    result = super

    if result['authentication'] && result['authentication']['credentials']
      result['authentication']['credentials']['password'] = VCAP::CloudController::Presenters::Censorship::PRIVATE_DATA_HIDDEN
    end

    result
  end
end
