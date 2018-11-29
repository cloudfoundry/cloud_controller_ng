module VCAP::CloudController
  class ProcessTypes
    WEB = 'web'.freeze

    def self.legacy_webish?(type)
      type.starts_with?('web-deployment-')
    end
  end
end
