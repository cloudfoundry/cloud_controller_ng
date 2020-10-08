module VCAP::CloudController
  class PackageModel < Sequel::Model(:packages)
    PACKAGE_STATES = [
      PENDING_STATE = 'PROCESSING_UPLOAD'.freeze,
      READY_STATE   = 'READY'.freeze,
      FAILED_STATE  = 'FAILED'.freeze,
      CREATED_STATE = 'AWAITING_UPLOAD'.freeze,
      COPYING_STATE = 'COPYING'.freeze,
      EXPIRED_STATE = 'EXPIRED'.freeze
    ].map(&:freeze).freeze

    PACKAGE_TYPES = [
      BITS_TYPE   = 'bits'.freeze,
      DOCKER_TYPE = 'docker'.freeze
    ].map(&:freeze).freeze

    one_to_many :droplets, class: 'VCAP::CloudController::DropletModel', key: :package_guid, primary_key: :guid
    many_to_one :app, class: 'VCAP::CloudController::AppModel', key: :app_guid, primary_key: :guid, without_guid_generation: true
    one_through_one :space, join_table: AppModel.table_name, left_key: :guid, left_primary_key: :app_guid, right_primary_key: :guid, right_key: :space_guid

    one_to_one :latest_droplet, class: 'VCAP::CloudController::DropletModel',
                                key: :package_guid, primary_key: :guid,
                                order: [Sequel.desc(:created_at), Sequel.desc(:id)], limit: 1

    one_to_many :labels, class: 'VCAP::CloudController::PackageLabelModel', key: :resource_guid, primary_key: :guid
    one_to_many :annotations, class: 'VCAP::CloudController::PackageAnnotationModel', key: :resource_guid, primary_key: :guid

    add_association_dependencies labels: :destroy
    add_association_dependencies annotations: :destroy

    set_field_as_encrypted :docker_password, salt: :docker_password_salt, column: :encrypted_docker_password

    def validate
      validates_max_length 5_000, :docker_password, message: 'can be up to 5,000 characters', allow_nil: true
      validates_includes PACKAGE_STATES, :state, allow_missing: true
      errors.add(:type, 'cannot have docker data if type is bits') if docker_image && type != DOCKER_TYPE
    end

    def image
      docker_image
    end

    def bits_image_reference(digest: false)
      config = VCAP::CloudController::Config.config
      raise 'Package Registry is not configured' unless config.package_image_registry_configured?
      raise 'Package type must be bits' unless bits?

      package_registry_base_path = config.get(:packages, :image_registry, :base_path)

      reference = "#{package_registry_base_path}/#{guid}"
      reference += "@sha256:#{sha256_checksum}" if digest

      reference
    end

    def bits?
      type == BITS_TYPE
    end

    def docker?
      type == DOCKER_TYPE
    end

    def failed?
      state == FAILED_STATE
    end

    def ready?
      state == READY_STATE
    end

    def checksum_info
      if sha256_checksum.blank? && package_hash.present?
        {
          type:  'sha1',
          value: package_hash,
        }
      else
        {
          type:  'sha256',
          value: sha256_checksum,
        }
      end
    end

    def succeed_upload!(checksums)
      return unless self.exists?

      db.transaction do
        self.lock!
        self.package_hash = checksums[:sha1]
        self.sha256_checksum = checksums[:sha256]
        self.state = VCAP::CloudController::PackageModel::READY_STATE
        self.save
      end
    end

    def fail_upload!(err_msg)
      db.transaction do
        self.lock!
        self.state = VCAP::CloudController::PackageModel::FAILED_STATE
        self.error = err_msg
        self.save
      end
    end
  end
end
