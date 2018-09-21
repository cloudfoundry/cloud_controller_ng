# Be sure to restart your server when you modify this file.

module CCInitializers
  def self.session_store(_)
    Rails.application.config.session_store :cookie_store, key: '_application_session'
  end
end
