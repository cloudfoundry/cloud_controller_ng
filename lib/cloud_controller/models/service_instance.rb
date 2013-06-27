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

    def validate
      validates_presence :name
      validates_presence :space
      validates_unique   [:space_id, :name]
    end

    def credentials=(val)
      json = Yajl::Encoder.encode(val)
      generate_salt
      encrypted_string = VCAP::CloudController::Encryptor.encrypt(json, salt)
      super(encrypted_string)
    end

    def credentials
      return unless super
      json = VCAP::CloudController::Encryptor.decrypt(super, salt)
      Yajl::Parser.parse(json) if json
    end

    def generate_salt
      self.salt ||= VCAP::CloudController::Encryptor.generate_salt
    end
  end
end
