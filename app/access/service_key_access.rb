module VCAP::CloudController
  class ServiceKeyAccess < BaseAccess
    def create?(service_key, params=nil)
      return true if admin_user?
      return false if service_key.in_suspended_org?
      service_key.service_instance.space.has_developer?(context.user)
    end

    def delete?(service_key)
      create?(service_key)
    end

    def read?(service_key)
      return true if admin_user?
      service_key.service_instance.space.has_developer?(context.user)
    end

    def index?(_, params=nil)
      return true if admin_user?
      return true unless params && params.key?(:related_obj)
      params[:related_obj].space.has_developer?(context.user)
    end
  end
end
