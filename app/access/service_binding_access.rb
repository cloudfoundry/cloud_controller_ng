module VCAP::CloudController
  class ServiceBindingAccess < BaseAccess
    def create?(service_binding, params=nil)
      raise 'callers should use Membership to determine this'
    end

    def delete?(service_binding)
      raise 'callers should use Membership to determine this'
    end

    def read_env?(service_binding)
      return true if admin_user? || admin_read_only_user?
      service_binding.space.has_developer?(context.user)
    end

    def read_env_with_token?(service_binding)
      read_with_token?(service_binding)
    end
  end
end
