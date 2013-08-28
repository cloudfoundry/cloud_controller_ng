module VCAP::CloudController::Models
  class OrganizationAccess < BaseAccess
    def update?(org)
      super || (org.managers.include?(context.user) && org.active? && !org.changed_columns.include?(:name))
    end
  end
end
