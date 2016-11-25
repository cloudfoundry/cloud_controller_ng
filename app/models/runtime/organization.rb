module VCAP::CloudController
  class Organization < Sequel::Model
    ORG_NAME_REGEX = /\A[[:alnum:][:punct:][:print:]]+\Z/
    ORG_STATUS_VALUES = %w(active suspended).freeze

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
      before_add: proc { cannot_create! },
      before_remove: proc { cannot_update! }

    one_to_many :service_instances,
                dataset: -> { VCAP::CloudController::ServiceInstance.filter(space: spaces) }

    one_to_many :managed_service_instances,
                dataset: -> { VCAP::CloudController::ServiceInstance.filter(space: spaces, is_gateway_service: true) }

    one_to_many :apps,
                dataset: -> { App.filter(space: spaces, type: 'web') }

    one_to_many :processes,
                dataset: -> { App.filter(space: spaces) }

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
        VCAP::CloudController::Domain.dataset.where(owning_organization_id: self.id).
          or(id: db[r.join_table_source].select(r.qualified_right_key).where(r.predicate_key => self.id))
      },
      before_add: proc { |org, private_domain| private_domain.addable_to_organization?(org) },
      before_remove: proc { |org, private_domain| !private_domain.owned_by?(org) },
      after_remove: proc { |org, private_domain| private_domain.routes_dataset.filter(space: org.spaces_dataset).destroy }
    )

    one_to_many(
      :owned_private_domains,
      class: 'VCAP::CloudController::PrivateDomain',
      read_only: true,
      key: :owning_organization_id,
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
                    id_map[org.id] = org
                  end

                  ds = Domain.shared_or_owned_by(id_map.keys)
                  ds = ds.eager(eo[:associations]) if eo[:associations]
                  ds = eo[:eager_block].call(ds) if eo[:eager_block]

                  ds.all do |domain|
                    if domain.shared?
                      id_map.each { |_, org| org.associations[:domains] << domain }
                    else
                      id_map[domain.owning_organization_id].associations[:domains] << domain
                    end
                  end
                }

    one_to_many :space_quota_definitions,
                before_add: proc { |org, quota| quota.organization.id == org.id }

    many_to_many(
      :private_stacks,
      class: 'VCAP::CloudController::Stack',
      join_table: 'organizations_private_stacks',
      left_key: :organization_id,
      right_key: :private_stack_id,
      before_add: :validate_add_private_stack
    )

    add_association_dependencies(
      owned_private_domains: :destroy,
      private_domains: :nullify,
      private_stacks: :nullify,
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

    def self.user_visibility_filter(user)
      {
        id: dataset.join_table(:inner, :organizations_managers, organization_id: :id, user_id: user.id).select(:organizations__id).union(
          dataset.join_table(:inner, :organizations_users, organization_id: :id, user_id: user.id).select(:organizations__id)
          ).union(
            dataset.join_table(:inner, :organizations_billing_managers, organization_id: :id, user_id: user.id).select(:organizations__id)
          ).union(
            dataset.join_table(:inner, :organizations_auditors, organization_id: :id, user_id: user.id).select(:organizations__id)
          ).select(:id)
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
      update(default_isolation_segment_model: nil)
      remove_all_isolation_segment_models
      super
    end

    def before_save
      if column_changed?(:billing_enabled) && billing_enabled?
        @is_billing_enabled = true
      end

      validate_quota

      super
    end

    def validate
      validates_presence :name
      validates_unique :name
      validates_format ORG_NAME_REGEX, :name
      validates_includes ORG_STATUS_VALUES, :status, allow_missing: true
    end

    def has_remaining_memory(mem)
      memory_remaining >= mem
    end

    def instance_memory_limit
      quota_definition ? quota_definition.instance_memory_limit : QuotaDefinition::UNLIMITED
    end

    def app_task_limit
      quota_definition ? quota_definition.app_task_limit : QuotaDefinition::UNLIMITED
    end

    def meets_max_task_limit?
      app_task_limit == running_and_pending_tasks_count
    end

    def active?
      status == 'active'
    end

    def suspended?
      status == 'suspended'
    end

    def billing_enabled?
      billing_enabled
    end

    def check_spaces_without_isolation_segments_empty!(action)
      Space.dataset.where(isolation_segment_guid: nil, organization: self).each do |space|
        raise CloudController::Errors::ApiError.new_from_details(
          'UnableToPerform',
          "#{action} default Isolation Segment",
          "Please delete all Apps from Space #{space.name} first.") unless space.app_models.empty?
      end
    end

    private

    def validate_quota_on_create
      return if quota_definition

      if QuotaDefinition.default.nil?
        err_msg = CloudController::Errors::ApiError.new_from_details('QuotaDefinitionNotFound', QuotaDefinition.default_quota_name).message
        raise CloudController::Errors::ApiError.new_from_details('OrganizationInvalid', err_msg)
      end
      self.quota_definition_id = QuotaDefinition.default.id
    end

    def validate_quota_on_update
      if column_changed?(:quota_definition_id) && quota_definition.nil?
        err_msg = CloudController::Errors::ApiError.new_from_details('QuotaDefinitionNotFound', 'null').message
        raise CloudController::Errors::ApiError.new_from_details('OrganizationInvalid', err_msg)
      end
    end

    def validate_quota
      new? ? validate_quota_on_create : validate_quota_on_update
    end

    def memory_remaining
      memory_used = processes_dataset.where(state: 'STARTED').sum(Sequel.*(:memory, :instances)) || 0
      quota_definition.memory_limit - memory_used
    end

    def running_and_pending_tasks_count
      tasks_dataset.where(state: [TaskModel::PENDING_STATE, TaskModel::RUNNING_STATE]).count
    end

    def validate_add_private_stack(stack)
      return if stack.is_private && !suspended?
      raise AssociationError.new
    end
  end
end
