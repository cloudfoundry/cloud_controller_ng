module VCAP::CloudController::Models
  class ProvidedServiceInstance < ServiceInstance
    def validate
      validates_presence :credentials
    end
  end
end
