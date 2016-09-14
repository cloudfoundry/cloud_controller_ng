module VCAP::CloudController
  class ServiceBindingAccess < BaseAccess
    def create?(service_binding, params=nil)
      raise 'callers should use Membership to determine this'
    end

    def delete?(service_binding)
      raise 'callers should use Membership to determine this'
    end
  end
end
