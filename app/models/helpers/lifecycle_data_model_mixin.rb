require 'cloud_controller/url_secret_obfuscator'

module LifecycleDataModelMixin
  def obfuscated_buildpacks
    buildpacks.map { |bp| CloudController::UrlSecretObfuscator.obfuscate(bp) }
  end
end
