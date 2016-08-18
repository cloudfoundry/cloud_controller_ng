module VCAP::CloudController
  class ServiceBindingModel < Sequel::Model(:v3_service_bindings)
    include Serializer
    class InvalidVolumeMount < StandardError; end

    many_to_one :service_instance
    many_to_one :app, class: 'VCAP::CloudController::AppModel'

    encrypt :credentials, salt: :salt
    serializes_via_json :credentials

    encrypt :volume_mounts, salt: :volume_mounts_salt
    serializes_via_json :volume_mounts

    delegate :client, :service, :service_plan,
      to: :service_instance

    plugin :after_initialize

    def validate
      validates_presence :service_instance
      validates_presence :app
      validates_presence :type
      validates_unique [:service_instance, :app]
      validate_space_match
      validate_cannot_change_binding

      validates_max_length 65_535, :volume_mounts if !volume_mounts.nil?
      validate_volume_mounts(volume_mounts)
    end

    def required_parameters
      { app_guid: app.guid }
    end

    def after_initialize
      super
      self.guid ||= SecureRandom.uuid
    end

    def space
      service_instance.space
    end

    private

    def validate_space_match
      return unless service_instance && app

      unless service_instance.space == app.space
        errors.add(:service_instance, :space_mismatch)
      end
    end

    def validate_volume_mounts(mounts_blob)
      return unless mounts_blob
      mounts = mounts_blob if mounts_blob.class == Array
      mounts = JSON.parse(mounts_blob.to_s) unless mounts_blob.class == Array
      return unless mounts

      raise InvalidVolumeMount.new('volume_mounts must be an Array but is ' + mounts.class.to_s) unless mounts.class == Array
      mounts.map! { |x| validate_mount(x) }
    end

    def validate_mount(mount_hash)
      raise InvalidVolumeMount.new('volume_mounts element must be an object but is ' + mount_hash.class.to_s) unless mount_hash.class == Hash
      %w(device_type device mode container_dir driver).each do |key|
        raise InvalidVolumeMount.new("missing required field '#{key}'") unless mount_hash.key?(key)
      end
      %w(device_type mode container_dir driver).each do |key|
        raise InvalidVolumeMount.new("required field '#{key}' must be a non-empty string") unless mount_hash[key].class == String && !mount_hash[key].empty?
      end
      raise InvalidVolumeMount.new("required field 'device' must be an object but is " + mount_hash['device'].class.to_s) unless mount_hash['device'].class == Hash
      raise InvalidVolumeMount.new("required field 'device.volume_id' must be a non-empty string") unless
          mount_hash['device']['volume_id'].class == String && !mount_hash['device']['volume_id'].empty?
      raise InvalidVolumeMount.new("field 'device.mount_config' must be an object if it is defined") unless
          !mount_hash['device'].key?('mount_config') || mount_hash['device']['mount_config'].class == Hash
    end

    def validate_cannot_change_binding
      return if new?

      app_change = column_change(:app_id)
      errors.add(:app, :invalid_relation) if app_change && app_change[0] != app_change[1]

      service_change = column_change(:service_instance_id)
      errors.add(:service_instance, :invalid_relation) if service_change && service_change[0] != service_change[1]
    end
  end
end
