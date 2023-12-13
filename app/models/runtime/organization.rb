require 'models/helpers/process_types'

module VCAP::CloudController
  class Organization < Sequel::Model
    ORG_NAME_REGEX = /\A[[:alnum:][:punct:][:print:]]+\Z/
    ACTIVE = 'active'.freeze
    SUSPENDED = 'suspended'.freeze
    ORG_STATUS_VALUES = [ACTIVE, SUSPENDED].freeze

    one_to_many :spaces

    many_to_one :default_isolation_segment_model,
                class: 'VCAP::CloudController::IsolationSegmentModel',
                primary_key: :guid,
                key: :default_isolation_segment_guid

    many_to_many :isolation_segment_models,
                 left_key: :organization_guid,
                 left_primary_key: :guid,
                 right_key: :isolation_segment_guid,
                 right_primary_key: :guid,
                 join_table: :organizations_isolation_segments,
                 # These are needed because we do not set the default isolation segment
                 # for an organization. This happens as part of the action on an
                 # Isolation Segment.
                 before_add: proc { cannot_create! },
                 before_remove: proc { cannot_update! }

    one_to_many :service_instances,
                dataset: -> { VCAP::CloudController::ServiceInstance.filter(space: spaces) }

    one_to_many :managed_service_instances,
                dataset: -> { VCAP::CloudController::ServiceInstance.filter(space: spaces, is_gateway_service: true) }

    one_to_many :apps,
                class: 'VCAP::CloudController::ProcessModel',
                dataset: -> { ProcessModel.filter(space: spaces, type: ProcessTypes::WEB) }

    one_to_many :processes,
                dataset: -> { ProcessModel.filter(space: spaces) }

    one_to_many :app_models,
                dataset: -> { AppModel.filter(space: spaces) }

    one_to_many :tasks,
                dataset: -> { TaskModel.filter(app: app_models) }

    one_to_many :app_events,
                dataset: -> { VCAP::CloudController::AppEvent.filter(app: apps) }

    many_to_many(
      :private_domains,
      class: 'VCAP::CloudController::PrivateDomain',
      right_key: :private_domain_id,
      dataset: proc { |r|
        # r.join_table_source = :organizations_private_domains
        # r.qualified_right_key = :private_domain_id
        # r.predicate_key = :organization_id
        VCAP::CloudController::Domain.dataset.where(owning_organization_id: id).
          or(id: db[r.join_table_source].select(r.qualified_right_key).where(r.predicate_key => id))
      },
      before_add: proc { |org, private_domain| org.cancel_action unless private_domain.addable_to_organization?(org) },
      before_remove: proc { |org, private_domain| org.cancel_action if private_domain.owned_by?(org) },
      after_remove: proc { |org, private_domain| private_domain.routes_dataset.filter(space: org.spaces_dataset).destroy },
      allow_eager: true
    )

    one_to_many(
      :owned_private_domains,
      class: 'VCAP::CloudController::PrivateDomain',
      read_only: true,
      key: :owning_organization_id
    )

    one_to_many :service_plan_visibilities
    many_to_one :quota_definition

    one_to_many :domains,
                dataset: -> { VCAP::CloudController::Domain.shared_or_owned_by(id) },
                remover: ->(legacy_domain) { legacy_domain.destroy if legacy_domain.owning_organization_id == id },
                clearer: -> { remove_all_private_domains },
                adder: ->(legacy_domain) { legacy_domain.addable_to_organization!(self) },
                eager_loader: proc { |eo|
                  id_map = {}
                  eo[:rows].each do |org|
                    org.associations[:domains] = []
                    id_map[org.id]             = org
                  end
                  ds = Domain.shared_or_owned_by(id_map.keys)
                  ds = ds.eager(eo[:associations]) if eo[:associations]
                  ds = eo[:eager_block].call(ds) if eo[:eager_block]
                  ds.all do |domain|
                    if domain.shared?
                      id_map.each_value { |org| org.associations[:domains] << domain }
                    else
                      id_map[domain.owning_organization_id].associations[:domains] << domain
                    end
                  end
                }

    one_to_many :space_quota_definitions,
                before_add: proc { |org, quota| org.cancel_action if quota.organization.id != org.id }

    one_to_many :labels, class: 'VCAP::CloudController::OrganizationLabelModel', key: :resource_guid, primary_key: :guid
    one_to_many :annotations, class: 'VCAP::CloudController::OrganizationAnnotationModel', key: :resource_guid, primary_key: :guid

    add_association_dependencies(
      owned_private_domains: :destroy,
      private_domains: :nullify,
      service_plan_visibilities: :destroy,
      space_quota_definitions: :destroy
    )

    define_user_group :users
    define_user_group :managers,
                      reciprocal: :managed_organizations
    define_user_group :billing_managers, reciprocal: :billing_managed_organizations
    define_user_group :auditors, reciprocal: :audited_organizations

    strip_attributes :name

    export_attributes :name, :billing_enabled, :quota_definition_guid, :status
    import_attributes :name, :billing_enabled,
                      :user_guids, :manager_guids, :billing_manager_guids,
                      :auditor_guids, :quota_definition_guid, :status, :default_isolation_segment_guid

    def remove_user(user)
      can_remove = ([user.spaces, user.audited_spaces, user.managed_spaces].flatten & spaces).empty?
      raise CloudController::Errors::ApiError.new_from_details('AssociationNotEmpty', 'user', 'spaces in the org') unless can_remove

      super(user)
    end

    def remove_user_recursive(user)
      ([user.spaces, user.audited_spaces, user.managed_spaces].flatten & spaces).each do |space|
        user.remove_spaces space
      end

      remove_user(user)
      remove_manager(user)
      remove_billing_manager(user)
      remove_auditor(user)
    end

    def add_auditor(user)
      OrganizationAuditor.find_or_create(user_id: user.id, organization_id: id)
      reload
    end

    def add_manager(user)
      OrganizationManager.find_or_create(user_id: user.id, organization_id: id)
      reload
    end

    def add_billing_manager(user)
      OrganizationBillingManager.find_or_create(user_id: user.id, organization_id: id)
      reload
    end

    def add_user(user)
      OrganizationUser.find_or_create(user_id: user.id, organization_id: id)
      reload
    end

    def self.user_visibility_filter(user)
      {
        id: user.membership_org_ids
      }
    end

    def self.cannot_create!
      raise CloudController::Errors::ApiError.new_from_details(
        'UnprocessableEntity',
        'Cannot create Organization<->Isolation Segment relationships via the Organizations endpoint'
      )
    end

    def self.cannot_update!
      raise CloudController::Errors::ApiError.new_from_details(
        'UnprocessableEntity',
        'Cannot delete Organization<->Isolation Segment relationships via the Organizations endpoint'
      )
    end

    def before_destroy
      @destroying = true

      # Unfortunately, because v2 non-recursive deletes expect labels and annotations to be
      # recursively deleted, we can't use association_dependencies like most other models.
      # The reason they are still deleted is because they would be stale metadata.
      # TODO: Change this to use add_association_dependencies when v2 is removed
      LabelDelete.delete(labels)
      AnnotationDelete.delete(annotations)
      # This is a Database.update(default_isolation_segment_guid), not a
      # Model.update(default_isolation_segment_model). This way our model guards
      # do not block us from removing the default_isolation_segment.
      update(default_isolation_segment_guid: nil)
      remove_all_isolation_segment_models
      super
    end

    def before_save
      @is_billing_enabled = true if column_changed?(:billing_enabled) && billing_enabled?

      validate_quota

      super
    end

    def validate
      validates_presence :name
      validates_unique :name
      validates_format ORG_NAME_REGEX, :name
      validates_includes ORG_STATUS_VALUES, :status, allow_missing: true

      return unless column_changed?(:default_isolation_segment_guid)

      validate_default_isolation_segment
    end

    def memory_used
      started_app_memory + running_task_memory
    end

    def has_remaining_memory(mem)
      quota_definition.memory_limit == QuotaDefinition::UNLIMITED || memory_remaining >= mem
    end

    def has_remaining_log_rate_limit(log_rate_limit_desired)
      quota_definition.log_rate_limit == QuotaDefinition::UNLIMITED || log_rate_limit_remaining >= log_rate_limit_desired
    end

    def instance_memory_limit
      quota_definition ? quota_definition.instance_memory_limit : QuotaDefinition::UNLIMITED
    end

    def log_rate_limit
      quota_definition ? quota_definition.log_rate_limit : QuotaDefinition::UNLIMITED
    end

    def app_task_limit
      quota_definition ? quota_definition.app_task_limit : QuotaDefinition::UNLIMITED
    end

    def meets_max_task_limit?
      app_task_limit <= running_and_pending_tasks_count
    end

    def active?
      status == ACTIVE
    end

    def suspended?
      status == SUSPENDED
    end

    def billing_enabled?
      billing_enabled
    end

    def isolation_segment_guids
      isolation_segment_models.map(&:guid)
    end

    def has_user?(user)
      user.present? && users_dataset.where(user_id: user.id).any?
    end

    def default_domain
      SharedDomain.where(internal: false, router_group_guid: nil).order(Sequel.asc(:id)).first || private_domains.first
    end

    def members
      User.where(id: Role.where(organization_id: id).distinct.select(:user_id))
    end

    def running_and_pending_tasks_count
      VCAP::CloudController::TaskModel.dataset.where(state: [TaskModel::PENDING_STATE, TaskModel::RUNNING_STATE]).
        join(:apps, guid: :app_guid).
        join(:spaces, guid: :space_guid).
        where(spaces__organization_id: id).
        count
    end

    private

    def validate_default_isolation_segment
      return if @destroying
      return if default_isolation_segment_model.nil?

      validate_default_isolation_segment_exists
    end

    def validate_default_isolation_segment_exists
      return if isolation_segment_guids.include?(default_isolation_segment_model.guid)

      raise CloudController::Errors::ApiError.new_from_details('InvalidRelation',
                                                               "Could not find Isolation Segment with guid: #{default_isolation_segment_model.guid}")
    end

    def validate_quota_on_create
      return if quota_definition

      if QuotaDefinition.default.nil?
        err_msg = CloudController::Errors::ApiError.new_from_details('QuotaDefinitionNotFound', QuotaDefinition.default_quota_name).message
        raise CloudController::Errors::ApiError.new_from_details('OrganizationInvalid', err_msg)
      end
      self.quota_definition_id = QuotaDefinition.default.id
    end

    def validate_quota_on_update
      return unless column_changed?(:quota_definition_id) && quota_definition.nil?

      err_msg = CloudController::Errors::ApiError.new_from_details('QuotaDefinitionNotFound', 'null').message
      raise CloudController::Errors::ApiError.new_from_details('OrganizationInvalid', err_msg)
    end

    def validate_quota
      new? ? validate_quota_on_create : validate_quota_on_update
    end

    def memory_remaining
      quota_definition.memory_limit - memory_used
    end

    def log_rate_limit_remaining
      quota_definition.log_rate_limit - (started_app_log_rate_limit + running_task_log_rate_limit)
    end

    def running_task_memory
      tasks_dataset.where(state: TaskModel::RUNNING_STATE).sum(:memory_in_mb) || 0
    end

    def started_app_memory
      processes_dataset.where(state: ProcessModel::STARTED).sum(Sequel.*(:memory, :instances)) || 0
    end

    def running_task_log_rate_limit
      tasks_dataset.where(state: TaskModel::RUNNING_STATE).sum(:log_rate_limit) || 0
    end

    def started_app_log_rate_limit
      processes_dataset.where(state: ProcessModel::STARTED).sum(Sequel.*(:log_rate_limit, :instances)) || 0
    end
  end
end
