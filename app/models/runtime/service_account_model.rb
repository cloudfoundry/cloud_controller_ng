module VCAP::CloudController
  class ServiceAccountModel < Sequel::Model(:service_accounts)
    NAME_PATTERN = /\A[a-z0-9][a-z0-9-]{1,61}[a-z0-9]\z/

    many_to_one :space, key: :space_guid, primary_key: :guid, without_guid_generation: true
    many_to_one :organization
    many_to_many :entitled_spaces,
                 class: 'VCAP::CloudController::Space',
                 join_table: :service_account_space_entitlements,
                 left_key: :service_account_guid, left_primary_key: :guid,
                 right_key: :space_guid, right_primary_key: :guid
    one_to_many :apps, class: 'VCAP::CloudController::AppModel', key: :service_account_guid, primary_key: :guid
    one_to_many :labels, class: 'VCAP::CloudController::ServiceAccountLabelModel', key: :resource_guid, primary_key: :guid
    one_to_many :annotations, class: 'VCAP::CloudController::ServiceAccountAnnotationModel', key: :resource_guid, primary_key: :guid
    add_association_dependencies labels: :destroy, annotations: :destroy

    def before_validation
      self.organization = space.organization if new? && organization_id.nil? && space
      super
    end

    def validate
      super
      validates_presence :space if new?
      validates_presence :organization
      errors.add(:organization, 'must own the initial space') if new? && space && organization_id != space.organization_id
      errors.add(:organization, 'is immutable') if !new? && column_changed?(:organization_id)
      validates_format NAME_PATTERN, :name
      errors.add(:name, 'is immutable') if !new? && column_changed?(:name)
      errors.add(:space, 'is immutable') if !new? && column_changed?(:space_guid) && space_guid
    end

    def around_create
      db.transaction(savepoint: true) do
        # Keep this reservation permanently, even when the account is destroyed.
        # The unique constraint, rather than a preflight query, serializes claims.
        db[:service_account_names].insert(name: name) # rubocop:disable Rails/SkipsModelValidations -- Atomic namespace reservation, not an ActiveRecord model.
        yield
      end
    rescue Sequel::UniqueConstraintViolation
      errors.add(:name, 'is already reserved')
      raise validation_failed_error
    end

    def after_create
      super
      add_entitled_space(space)
    end

    def client_id
      "cf:service-account:#{name}"
    end

    def in_use?
      apps_dataset.any? ||
        ProcessModel.where(service_account_guid: guid, state: ProcessModel::STARTED).any? ||
        TaskModel.where(service_account_guid: guid, state: [TaskModel::PENDING_STATE, TaskModel::RUNNING_STATE, TaskModel::CANCELING_STATE]).any?
    end

    def certificate_dns_san
      "#{name}.svc.identity"
    end
  end
end
