require 'repositories/services/service_usage_event_repository'

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
    many_to_one :space, :after_set => :validate_space

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
      validates_unique [:space_id, :name], where: (proc do |_, obj, arr|
          vals = arr.map{|x| obj.send(x)}
          next if vals.any?{|v| v.nil?}
          ServiceInstance.where(arr.zip(vals))
        end)
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

    def to_hash(opts={})
      if !VCAP::CloudController::SecurityContext.admin? && !space.developers.include?(VCAP::CloudController::SecurityContext.current_user)
        opts.merge!({redact: ['credentials']})
      end
      super(opts)
    end

    def credentials=(val)
      if val
        json = MultiJson.dump(val)
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
      MultiJson.load(json) if json
    end

    def in_suspended_org?
      space.in_suspended_org?
    end

    def after_create
      super
      service_instance_usage_event_repository.created_event_from_service_instance(self)
    end

    def after_destroy
      super
      service_instance_usage_event_repository.deleted_event_from_service_instance(self)
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

    def validate_space(space)
       service_bindings.each{ |binding| validate_service_binding(binding) }
    end

    def service_instance_usage_event_repository
      @repository ||= Repositories::Services::ServiceUsageEventRepository.new
    end
  end
end
