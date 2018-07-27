require 'models/helpers/process_types'

module VCAP::CloudController
  class Space < Sequel::Model
    class InvalidDeveloperRelation < CloudController::Errors::InvalidRelation; end
    class InvalidAuditorRelation < CloudController::Errors::InvalidRelation; end
    class InvalidManagerRelation < CloudController::Errors::InvalidRelation; end
    class InvalidSpaceQuotaRelation < CloudController::Errors::InvalidRelation; end
    class UnauthorizedAccessToPrivateDomain < RuntimeError; end

    SPACE_NAME_REGEX = /\A[[:alnum:][:punct:][:print:]]+\Z/

    plugin :many_through_many

    many_to_one :isolation_segment_model,
       primary_key: :guid,
       key: :isolation_segment_guid

    define_user_group :developers, reciprocal: :spaces, before_add: :validate_developer
    define_user_group :managers, reciprocal: :managed_spaces, before_add: :validate_manager
    define_user_group :auditors, reciprocal: :audited_spaces, before_add: :validate_auditor

    many_to_one :organization, before_set: :validate_change_organization

    one_to_many :app_models, primary_key: :guid, key: :space_guid

    one_to_many :processes, class: 'VCAP::CloudController::ProcessModel', dataset: -> { ProcessModel.filter(app: app_models) }

    many_through_many :apps, [
      [:spaces, :id, :guid],
      [:apps, :space_guid, :guid]
    ], class: 'VCAP::CloudController::ProcessModel', right_primary_key: :app_guid, conditions: { type: ProcessTypes::WEB }

    one_to_many :events, primary_key: :guid, key: :space_guid
    one_to_many :service_instances
    one_to_many :managed_service_instances
    many_to_many :service_instances_shared_from_other_spaces,
          left_key:          :target_space_guid,
          left_primary_key:  :guid,
          right_key:         :service_instance_guid,
          right_primary_key: :guid,
          join_table:        :service_instance_shares,
          class: 'VCAP::CloudController::ServiceInstance'

    one_to_many :service_brokers
    one_to_many :routes
    one_to_many :tasks,
                dataset: -> { TaskModel.filter(app: app_models) }
    many_to_many :security_groups,
    dataset: -> {
      SecurityGroup.left_join(:security_groups_spaces, security_group_id: :id).
        where(Sequel.or(security_groups_spaces__space_id: id, security_groups__running_default: true)).distinct(:id)
    },
    eager_loader: ->(spaces_map) {
      space_ids = spaces_map[:id_map].keys
      # Set all associations to nil so if no records are found, we don't do another query when somebody tries to load the association
      spaces_map[:rows].each { |space| space.associations[:security_groups] = [] }
      default_security_groups = SecurityGroup.where(running_default: true).all
      SecurityGroupsSpace.where(space_id: space_ids).eager(:security_group).all do |security_group_space|
        space = spaces_map[:id_map][security_group_space.space_id].first
        space.associations[:security_groups] << security_group_space.security_group
      end
      spaces_map[:rows].each do |space|
        space.associations[:security_groups] += default_security_groups
        space.associations[:security_groups].uniq!
      end
    }

    many_to_many :staging_security_groups,
    class: 'VCAP::CloudController::SecurityGroup',
    join_table: 'staging_security_groups_spaces',
    left_key: :staging_space_id,
    right_key: :staging_security_group_id,
    dataset: -> {
      SecurityGroup.left_join(:staging_security_groups_spaces, staging_security_group_id: :id).
        where(Sequel.or(staging_security_groups_spaces__staging_space_id: id, security_groups__staging_default: true)).distinct(:id)
    },
    eager_loader: ->(spaces_map) {
      space_ids = spaces_map[:id_map].keys
      # Set all associations to nil so if no records are found, we don't do another query when somebody tries to load the association
      spaces_map[:rows].each { |space| space.associations[:staging_security_groups] = [] }
      default_security_groups = SecurityGroup.where(staging_default: true).all
      StagingSecurityGroupsSpace.where(staging_space_id: space_ids).eager(:security_group).all do |security_group_space|
        space = spaces_map[:id_map][security_group_space.staging_space_id].first
        space.associations[:staging_security_groups] << security_group_space.security_group
      end
      spaces_map[:rows].each do |space|
        space.associations[:staging_security_groups] += default_security_groups
        space.associations[:staging_security_groups].uniq!
      end
    }

    one_to_many :app_events,
      dataset: -> { AppEvent.filter(app: apps) }

    one_to_many :default_users, class: 'VCAP::CloudController::User', key: :default_space_id

    one_to_many :domains,
      dataset: -> { organization.domains_dataset },
      adder: ->(domain) { domain.addable_to_organization!(organization) },
      eager_loader: proc { |eo|
        id_map = {}
        eo[:rows].each do |space|
          space.associations[:domains] = []
          id_map[space.organization_id] ||= []
          id_map[space.organization_id] << space
        end
        ds = Domain.shared_or_owned_by(id_map.keys)
        ds = ds.eager(eo[:associations]) if eo[:associations]
        ds = eo[:eager_block].call(ds) if eo[:eager_block]
        ds.all do |domain|
          if domain.shared?
            id_map.each_value { |spaces| spaces.each { |space| space.associations[:domains] << domain } }
          else
            id_map[domain.owning_organization_id].each { |space| space.associations[:domains] << domain }
          end
        end
      }

    many_to_one :space_quota_definition

    add_association_dependencies(
      default_users: :nullify,
      processes: :destroy,
      routes: :destroy,
      security_groups: :nullify,
      staging_security_groups: :nullify,
    )

    export_attributes :name, :organization_guid, :space_quota_definition_guid, :allow_ssh

    import_attributes :name, :organization_guid, :developer_guids, :allow_ssh, :isolation_segment_guid,
      :manager_guids, :auditor_guids, :security_group_guids, :space_quota_definition_guid

    strip_attributes :name

    dataset_module do
      def having_developers(*users)
        join(:spaces_developers, spaces_developers__space_id: :spaces__id).
          where(spaces_developers__user_id: users.map(&:id)).select_all(:spaces)
      end
    end

    def has_developer?(user)
      user.present? && developers_dataset.where(user_id: user.id).present?
    end

    def has_member?(user)
      has_developer?(user) || has_manager?(user) || has_auditor?(user)
    end

    def in_organization?(user)
      organization && organization.has_user?(user)
    end

    def validate
      validates_presence :name
      validates_presence :organization
      validates_unique [:organization_id, :name]
      validates_format SPACE_NAME_REGEX, :name

      if space_quota_definition && space_quota_definition.organization.guid != organization.guid
        errors.add(:space_quota_definition, :invalid_organization)
      end

      if column_changed?(:isolation_segment_guid)
        validate_isolation_segment(isolation_segment_model)
      end
    end

    def validate_isolation_segment(isolation_segment_model)
      validate_isolation_segment_set(isolation_segment_model) if isolation_segment_model
    end

    def validate_developer(user)
      raise InvalidDeveloperRelation.new(user.guid) unless in_organization?(user)
    end

    def validate_manager(user)
      raise InvalidManagerRelation.new(user.guid) unless in_organization?(user)
    end

    def validate_auditor(user)
      raise InvalidAuditorRelation.new(user.guid) unless in_organization?(user)
    end

    def validate_change_organization(new_org)
      raise CloudController::Errors::ApiError.new_from_details('OrganizationAlreadySet') unless organization.nil? || organization.guid == new_org.guid
    end

    def self.user_visibility_filter(user)
      {
        spaces__id: dataset.join_table(:inner, :spaces_developers, space_id: :id, user_id: user.id).select(:spaces__id).
          union(dataset.join_table(:inner, :spaces_managers, space_id: :id, user_id: user.id).select(:spaces__id)).
          union(dataset.join_table(:inner, :spaces_auditors, space_id: :id, user_id: user.id).select(:spaces__id)).
          union(dataset.join_table(:inner, :organizations_managers, organization_id: :organization_id, user_id: user.id).select(:spaces__id)).
          select(:id)
      }
    end

    def has_remaining_memory(mem)
      return true unless space_quota_definition
      memory_remaining >= mem
    end

    def instance_memory_limit
      if space_quota_definition
        space_quota_definition.instance_memory_limit
      else
        SpaceQuotaDefinition::UNLIMITED
      end
    end

    def app_task_limit
      if space_quota_definition
        space_quota_definition.app_task_limit
      else
        SpaceQuotaDefinition::UNLIMITED
      end
    end

    def meets_max_task_limit?
      app_task_limit == running_and_pending_tasks_count
    end

    def in_suspended_org?
      organization.suspended?
    end

    private

    def has_manager?(user)
      user.present? && managers_dataset.where(user_id: user.id).present?
    end

    def has_auditor?(user)
      user.present? && auditors_dataset.where(user_id: user.id).present?
    end

    def memory_remaining
      memory_used = started_app_memory + running_task_memory
      space_quota_definition.memory_limit - memory_used
    end

    def running_task_memory
      tasks_dataset.where(state: TaskModel::RUNNING_STATE).sum(:memory_in_mb) || 0
    end

    def started_app_memory
      processes_dataset.where(state: ProcessModel::STARTED).sum(Sequel.*(:memory, :instances)) || 0
    end

    def running_and_pending_tasks_count
      tasks_dataset.where(state: [TaskModel::PENDING_STATE, TaskModel::RUNNING_STATE]).count
    end

    def validate_isolation_segment_set(isolation_segment_model)
      isolation_segment_guids = organization.isolation_segment_models.map(&:guid)
      unless isolation_segment_guids.include?(isolation_segment_model.guid)
        raise CloudController::Errors::ApiError.new_from_details('UnableToPerform',
                                                                 'Adding the Isolation Segment to the Space',
                                                                 "Only Isolation Segments in the Organization's allowed list can be used.")
      end
    end
  end
end
