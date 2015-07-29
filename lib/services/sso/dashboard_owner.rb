module VCAP::Services::SSO
  class DashboardOwner
    attr_accessor :is_instance
    delegate :id, :db, :guid, :name, to: :owner

    def initialize(owner, is_instance: false)
      @owner = owner
      @is_instance = is_instance
    end

    def metadata(client_attrs)
      metadata = {}
      if client_attrs.key?('redirect_uri')
        metadata = {
          secret: '[REDACTED]',
          redirect_uri: client_attrs['redirect_uri'],
        }
      end
      metadata[:service_instance_guid] = owner.guid if is_instance
      metadata
    end

    def broker
      if is_instance
        owner.service_broker
      else
        owner
      end
    end

    private

    attr_accessor :owner
  end
end
