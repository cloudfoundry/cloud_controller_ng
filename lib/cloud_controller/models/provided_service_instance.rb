module VCAP::CloudController::Models
  class ProvidedServiceInstance < ServiceInstance
    # sad: can we declare this in parent class one day?
    strip_attributes :name

    def validate
      validates_presence :credentials
    end
  end
end
