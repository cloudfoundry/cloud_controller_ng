module VCAP::CloudController
  module Repositories
    module Services
      class EventRepository

        def create_audit_event(type, broker, params)
          user = SecurityContext.current_user

          request_hash = {}
          [:name, :broker_url, :auth_username].each do |key|
            request_hash[key] = params[key] unless params[key].nil?
          end
          request_hash[:auth_password] = '[REDACTED]' if params.has_key? :auth_password

          metadata = {}
          if request_hash.length > 0
            metadata[:request] = request_hash
          end

          Event.create(
              type: type,
              actor_type: 'user',
              actor: user.guid,
              actor_name: SecurityContext.current_user_email,
              timestamp: Time.now,
              actee: broker.guid,
              actee_type: 'broker',
              actee_name: broker.name,
              space_guid: '',  #empty since brokers don't associate to spaces
              organization_guid: '',
              metadata: metadata,
            )
        end
      end
    end
  end
end
