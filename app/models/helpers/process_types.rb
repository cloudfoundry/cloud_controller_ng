module VCAP::CloudController
  class ProcessTypes
    WEB = 'web'.freeze

    def self.webish?(type)
      type == WEB || type.starts_with?('web-deployment-')
    end
  end
end
