require 'models/helpers/process_types'
require 'cloud_controller/errors/invalid_relation'

module VCAP::CloudController
  class Space < Sequel::Model
    class InvalidDeveloperRelation < CloudController::Errors::InvalidRelation; end
    class InvalidAuditorRelation < CloudController::Errors::InvalidRelation; end
    class InvalidSupporterRelation < CloudController::Errors::InvalidRelation; end
    class InvalidManagerRelation < CloudController::Errors::InvalidRelation; end
    class InvalidSpaceQuotaRelation < CloudController::Errors::InvalidRelation; end
    class UnauthorizedAccessToPrivateDomain < RuntimeError; end
    class DBNameUniqueRaceError < Sequel::ValidationFailed; end

    SPACE_NAME_REGEX = /\A[[:alnum:][:punct:][:print:]]+\Z/.freeze
    SELECT_NEWEST_PROCESS = lambda { |_, processes|
      newest_processes = {}
      processes.group_by(&:app_guid).each do |_, processes_for_app|
        newest_process = processes_for_app.max_by { |p| [p.created_at, p.id] }
        newest_processes[newest_process.guid] = newest_process
      end
      processes.keep_if { |p| newest_processes[p.guid] }
    }

    plugin :many_through_many

    many_to_one :isolation_segment_model,
       primary_key: :guid,
       key: :isolation_segment_guid

    define_user_group :developers, reciprocal: :spaces, before_add: :validate_developer
    define_user_group :managers, reciprocal: :managed_spaces, before_add: :validate_manager
    define_user_group :auditors, reciprocal: :audited_spaces, before_add: :validate_auditor
    define_user_group :supporters, reciprocal: :supporter_spaces, before_add: :validate_supporter

    many_to_one :organization, before_set: :validate_change_organization

    one_to_many :app_models, primary_key: :guid, key: :space_guid

    one_to_many :processes, class: 'VCAP::CloudController::ProcessModel', dataset: -> { ProcessModel.filter(app: app_models) }

    one_to_many :labels, class: 'VCAP::CloudController::SpaceLabelModel', key: :resource_guid, primary_key: :guid
    one_to_many :annotations, class: 'VCAP::CloudController::SpaceAnnotationModel', key: :resource_guid, primary_key: :guid

    many_through_many :apps, [
      [:spaces, :id, :guid],
      [:apps, :space_guid, :guid]
    ], class: 'VCAP::CloudController::ProcessModel', right_primary_key: :app_guid, conditions: { type: ProcessTypes::WEB },
      after_load: SELECT_NEWEST_PROCESS

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

    many_to_many :routes_shared_from_other_spaces,
          left_key:          :target_space_guid,
          left_primary_key:  :guid,
          right_key:         :route_guid,
          right_primary_key: :guid,
          join_table:        :route_shares,
          class: 'VCAP::CloudController::Route'

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
      staging_security_groups: :nullify
    )

    # Unfortunately, because v2 non-recursive deletes expect labels and annotations to be
    # recursively deleted, we can't use association_dependencies like most other models.
    # The reason they are still deleted is because they would be stale metadata.
    # TODO: Change this to use add_association_dependencies when v2 is removed
    def before_destroy
      LabelDelete.delete(labels)
      AnnotationDelete.delete(annotations)
      super
    end

    export_attributes :name, :organization_guid, :space_quota_definition_guid, :allow_ssh

    import_attributes :name, :organization_guid, :developer_guids, :allow_ssh, :isolation_segment_guid,
      :manager_guids, :auditor_guids, :supporter_guids, :security_group_guids, :space_quota_definition_guid

    strip_attributes :name

    dataset_module do
      def having_developers(*users)
        join(:spaces_developers, spaces_developers__space_id: :spaces__id).
          where(spaces_developers__user_id: users.map(&:id)).select_all(:spaces)
      end
    end

    def add_auditor(user)
      validate_auditor(user)
      SpaceAuditor.find_or_create(user_id: user.id, space_id: id)
      self.reload
    end

    def add_supporter(user)
      validate_supporter(user)
      SpaceSupporter.find_or_create(user_id: user.id, space_id: id)
      self.reload
    end

    def add_manager(user)
      validate_manager(user)
      SpaceManager.find_or_create(user_id: user.id, space_id: id)
      self.reload
    end

    def add_developer(user)
      validate_developer(user)
      SpaceDeveloper.find_or_create(user_id: user.id, space_id: id)
      self.reload
    end

    def has_developer?(user)
      user.present? && developers_dataset.where(user_id: user.id).present?
    end

    def has_supporter?(user)
      user.present? && supporters_dataset.where(user_id: user.id).present?
    end

    def has_member?(user)
      has_developer?(user) || has_manager?(user) || has_auditor?(user)
    end

    def in_organization?(user)
      organization && organization.has_user?(user)
    end

    def around_save
      yield
    rescue Sequel::UniqueConstraintViolation => e
      raise DBNameUniqueRaceError.new(e) if e.message.try(:include?, 'spaces_org_id_name_index')

      raise
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

    def validate_supporter(user)
      raise InvalidSupporterRelation.new(user.guid) unless in_organization?(user)
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

    def find_visible_service_instance_by_name(name)
      shared = self.service_instances_shared_from_other_spaces_dataset.where(name: name).all
      source = self.service_instances_dataset.where(name: name).all

      (shared | source).first
    end

    def self.user_visibility_filter(user)
      {
        spaces__id: dataset.join_table(:inner, :spaces_developers, space_id: :id, user_id: user.id).select(:spaces__id).
          union(dataset.join_table(:inner, :spaces_managers, space_id: :id, user_id: user.id).select(:spaces__id)).
          union(dataset.join_table(:inner, :spaces_auditors, space_id: :id, user_id: user.id).select(:spaces__id)).
          union(dataset.join_table(:inner, :spaces_supporters, space_id: :id, user_id: user.id).select(:spaces__id)).
          union(dataset.join_table(:inner, :organizations_managers, organization_id: :organization_id, user_id: user.id).select(:spaces__id)).
          select(:id)
      }
    end

    def has_remaining_memory(mem)
      return true unless space_quota_definition

      space_quota_definition.memory_limit == SpaceQuotaDefinition::UNLIMITED || memory_remaining >= mem
    end

    def has_remaining_log_rate_limit(log_rate_limit_desired)
      return true unless space_quota_definition

      space_quota_definition.log_rate_limit == SpaceQuotaDefinition::UNLIMITED || log_rate_limit_remaining >= log_rate_limit_desired
    end

    def instance_memory_limit
      if space_quota_definition
        space_quota_definition.instance_memory_limit
      else
        SpaceQuotaDefinition::UNLIMITED
      end
    end

    def log_rate_limit
      if space_quota_definition
        space_quota_definition.log_rate_limit
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
      app_task_limit <= running_and_pending_tasks_count
    end

    def in_suspended_org?
      organization.suspended?
    end

    def members
      User.dataset.where(id: SpaceRole.where(space_id: id).select(:user_id))
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

    def log_rate_limit_remaining
      space_quota_definition.log_rate_limit - (started_app_log_rate_limit + running_task_log_rate_limit)
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
