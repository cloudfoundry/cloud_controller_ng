module VCAP::CloudController::Models
  class ServiceBroker < Sequel::Model
    import_attributes :name, :broker_url, :token
    export_attributes :name, :broker_url

    def self.user_visibility_filter(user)
      user_visibility_filter_with_admin_override(id: []) # awful hack: non-admins see no records
    end

    def validate
      validates_presence :name
      validates_presence :broker_url
      validates_presence :token
      validates_unique :name
      validates_unique :broker_url
    end

    def check!
      raise unless broker_url && token

      api_base_url = broker_url + '/v3'
      api_status_uri = URI(api_base_url)

      http = HTTPClient.new
      http.set_auth(api_base_url, 'cc', token)

      begin
        response = http.get(api_status_uri)
      rescue SocketError, HTTPClient::ConnectTimeoutError, Errno::ECONNREFUSED
        raise VCAP::Errors::ServiceBrokerApiUnreachable.new(broker_url)
      rescue HTTPClient::KeepAliveDisconnected, HTTPClient::ReceiveTimeoutError
        raise VCAP::Errors::ServiceBrokerApiTimeout.new(broker_url)
      end

      if response.code.to_i == HTTP::Status::UNAUTHORIZED
        raise VCAP::Errors::ServiceBrokerApiAuthenticationFailed.new(broker_url)
      elsif response.code.to_i != HTTP::Status::OK || response.body != '["OK"]'
        raise VCAP::Errors::ServiceBrokerApiInvalid.new(broker_url)
      end
    end
  end
end
