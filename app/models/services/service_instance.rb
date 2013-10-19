module VCAP::CloudController
  class ServiceInstance < Sequel::Model
    class InvalidServiceBinding < StandardError; end

    plugin :single_table_inheritance, :is_gateway_service,
           model_map: lambda { |is_gateway_service|
             if is_gateway_service
               VCAP::CloudController::ManagedServiceInstance
             else
               VCAP::CloudController::UserProvidedServiceInstance
             end
           },
           key_map: lambda { |klazz|
             klazz == VCAP::CloudController::ManagedServiceInstance
           }

    one_to_many :service_bindings, :before_add => :validate_service_binding
    many_to_one :space

    add_association_dependencies :service_bindings => :destroy

    def self.user_visibility_filter(user)
      Sequel.or([
        [:space, user.spaces_dataset],
        [:space, user.audited_spaces_dataset]
      ])
    end

    def type
      self.class.name.demodulize.underscore
    end

    def validate
      validates_presence :name
      validates_presence :space
      validates_unique [:space_id, :name]
      validates_max_length 50, :name
    end

    def credentials=(val)
      json = Yajl::Encoder.encode(val)
      generate_salt
      encrypted_string = VCAP::CloudController::Encryptor.encrypt(json, salt)
      super(encrypted_string)
    end

    def credentials
      return if super.blank?
      json = VCAP::CloudController::Encryptor.decrypt(super, salt)
      Yajl::Parser.parse(json) if json
    end

    def generate_salt
      self.salt ||= VCAP::CloudController::Encryptor.generate_salt
    end

    # Make sure all derived classes use the base access class
    def self.source_class
      ServiceInstance
    end

    def bindable?
      true
    end

    def as_summary_json
      {
        'guid' => guid,
        'name' => name,
        'bound_app_count' => service_bindings_dataset.count
      }
    end

    private
    def validate_service_binding(service_binding)
      if service_binding && service_binding.app.space != space
        raise InvalidServiceBinding.new(service_binding.id)
      end
    end
  end
end
