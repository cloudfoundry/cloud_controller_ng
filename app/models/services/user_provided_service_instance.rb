module VCAP::CloudController
  class UserProvidedServiceInstance < ServiceInstance
    export_attributes :name, :credentials, :space_guid, :type, :syslog_drain_url
    import_attributes :name, :credentials, :space_guid, :syslog_drain_url

    # sad: can we declare this in parent class one day
    strip_attributes :name, :syslog_drain_url

    add_association_dependencies :service_bindings => :destroy

    def validate
      super
    end

    def tags
      []
    end

    def client
      ServiceBroker::UserProvided::Client.new
    end

    def before_update
      if column_changed?(:credentials) or column_changed?(:syslog_drain_url)
        service_bindings.each do |binding|
          binding.update(
            :credentials      => self.credentials,
            :syslog_drain_url => self.syslog_drain_url
          )
        end
      end
      super
    end
  end
end
