module VCAP::CloudController::Models
  class ServiceInstance < Sequel::Model
    plugin :single_table_inheritance, :kind

    one_to_many :service_bindings, :before_add => :validate_service_binding
    many_to_one :space

    add_association_dependencies :service_bindings => :destroy

    def self.user_visibility_filter(user)
      user_visibility_filter_with_admin_override(
        :space => user.spaces_dataset)
    end
  end
end
