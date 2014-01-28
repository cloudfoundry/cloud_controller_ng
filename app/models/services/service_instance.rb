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

    many_to_one :service_plan_sti_eager_load,
                class: "VCAP::CloudController::ServicePlan",
                dataset: -> { raise "Must be used for eager loading" },
                eager_loader_key: nil, # set up id_map ourselves
                eager_loader: proc { |eo|
                  id_map = {}
                  eo[:rows].each do |service_instance|
                    service_instance.associations[:service_plan] = nil
                    id_map[service_instance.service_plan_id] ||= []
                    id_map[service_instance.service_plan_id] << service_instance
                  end

                  ds = ServicePlan.where(id: id_map.keys)
                  ds = ds.eager(eo[:associations]) if eo[:associations]
                  ds = eo[:eager_block].call(ds) if eo[:eager_block]

                  ds.all do |service_plan|
                    id_map[service_plan.id].each { |si| si.associations[:service_plan] = service_plan }
                  end
                }

    delegate :organization, to: :space

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

    def credentials=(val)
      if val
        json = Yajl::Encoder.encode(val)
        generate_salt
        encrypted_string = VCAP::CloudController::Encryptor.encrypt(json, salt)
        super(encrypted_string)
      else
        super(nil)
        self.salt = nil
      end
    end

    def credentials
      return if super.blank?
      json = VCAP::CloudController::Encryptor.decrypt(super, salt)
      Yajl::Parser.parse(json) if json
    end

    private

    def generate_salt
      self.salt ||= VCAP::CloudController::Encryptor.generate_salt
    end

    def validate_service_binding(service_binding)
      if service_binding && service_binding.app.space != space
        raise InvalidServiceBinding.new(service_binding.id)
      end
    end
  end
end
