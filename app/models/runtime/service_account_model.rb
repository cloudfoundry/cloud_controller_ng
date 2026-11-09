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
      self.identity_prefix = organization.service_account_prefix if new? && identity_prefix.nil? && organization
      super
    end

    def validate
      super
      validates_presence :space if new?
      validates_presence :organization
      errors.add(:organization, 'must own the initial space') if new? && space && organization_id != space.organization_id
      errors.add(:organization, 'is immutable') if !new? && column_changed?(:organization_id)
      validate_identity_immutability
      validates_format NAME_PATTERN, :name
      errors.add(:name, 'is immutable') if !new? && column_changed?(:name)
      errors.add(:space, 'is immutable') if !new? && column_changed?(:space_guid) && space_guid
    end

    def validate_identity_immutability
      errors.add(:identity_prefix, 'is immutable') if !new? && column_changed?(:identity_prefix)
    end

    def around_create
      db.transaction(savepoint: true) do
        # Keep this reservation permanently, even when the account is destroyed.
        # The unique constraint, rather than a preflight query, serializes claims.
        db[:service_account_names].insert(name: name, organization_id: organization_id) # rubocop:disable Rails/SkipsModelValidations -- Atomic namespace reservation, not an ActiveRecord model.
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
      identity_prefix ? "cf:service-account:#{identity_prefix}:#{name}" : "cf:service-account:#{name}"
    end

    def in_use?
      apps_dataset.any? ||
        ProcessModel.where(service_account_guid: guid, state: ProcessModel::STARTED).any? ||
        TaskModel.where(service_account_guid: guid, state: [TaskModel::PENDING_STATE, TaskModel::RUNNING_STATE, TaskModel::CANCELING_STATE]).any?
    end

    def in_use_in_space?(space)
      app_guids = AppModel.where(space_guid: space.guid).select(:guid)
      apps_dataset.where(space_guid: space.guid).any? ||
        ProcessModel.where(app_guid: app_guids, service_account_guid: guid, state: ProcessModel::STARTED).any? ||
        TaskModel.where(app_guid: app_guids, service_account_guid: guid, state: [TaskModel::PENDING_STATE, TaskModel::RUNNING_STATE, TaskModel::CANCELING_STATE]).any?
    end

    def entitled_to?(space)
      organization_id == space.organization_id && entitled_spaces_dataset.where(spaces__guid: space.guid).any?
    end

    def certificate_dns_san
      identity_prefix ? "#{name}.#{identity_prefix}.svc.identity" : "#{name}.svc.identity"
    end

    def before_destroy
      RoutePolicy.where(source_type: 'svc', source_guid: guid).all.each do |policy|
        policy.destroy
        policy.notify_diego
      end
      db[:service_account_names].where(name: name, organization_id: organization_id).update(deleted_at: Sequel::CURRENT_TIMESTAMP)
      super
    end
  end
end
