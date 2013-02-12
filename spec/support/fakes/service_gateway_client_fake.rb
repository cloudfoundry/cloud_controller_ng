module VCAP::Services::Api
  class ServiceGatewayClientFake < ServiceGatewayClient
    def provision(*_)
      GatewayHandleResponse.decode({:service_id => "SERVICE_ID", :configuration => 'CONFIGURATION', :credentials => {'password' => 'PASSWORD'}}.to_json)
    end

    def unprovision(*_); end

    def bind(*_)
      GatewayHandleResponse.decode({:service_id => "SERVICE_ID", :configuration => 'CONFIGURATION', :credentials => {'password' => 'PASSWORD'}}.to_json)
    end
  end
end
