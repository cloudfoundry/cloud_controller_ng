module I18nHelper
  def self.set_i18n_env
    I18n.enforce_available_locales = false
    I18n.load_path = Dir[File.expand_path("../../fixtures/i18n/*.yml", __FILE__)]
    I18n.default_locale = "en_US"
    I18n::Backend::Simple.send(:include, I18n::Backend::Fallbacks)
    I18n.backend.reload!
  end

  def self.clear_i18n_env
    I18n.locale = "en"
    I18n.load_path = []
    I18n.backend.reload!
  end
end