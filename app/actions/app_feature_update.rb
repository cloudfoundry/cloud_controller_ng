module VCAP::CloudController
  class AppFeatureUpdate
    def self.update(feature_name, app, message)
      case feature_name
      when 'ssh'
        app.update(enable_ssh: message.enabled)
      when 'revisions'
        app.update(revisions_enabled: message.enabled)
      end
    end
  end
end
