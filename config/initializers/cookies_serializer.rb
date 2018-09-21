# Be sure to restart your server when you modify this file.

module CCInitializers
  def self.cookies_serializer(_)
    # Specify a serializer for the signed and encrypted cookie jars.
    # Valid options are :json, :marshal, and :hybrid.
    Rails.application.config.action_dispatch.cookies_serializer = :marshal
  end
end
