require 'models/helpers/role_types'

module VCAP::CloudController
  SPACE_OR_ORGANIZATION_NOT_SPECIFIED = -1

  # Creates UNIONed dataset and supports building a dataset with filters (i.e. WHERE conditions) per role (i.e.
  # individual table).
  class RoleDataset
    class << self
      def model_by_role(role)
        case role
        when RoleTypes::ORGANIZATION_USER
          OrganizationUser
        when RoleTypes::ORGANIZATION_AUDITOR
          OrganizationAuditor
        when RoleTypes::ORGANIZATION_BILLING_MANAGER
          OrganizationBillingManager
        when RoleTypes::ORGANIZATION_MANAGER
          OrganizationManager
        when RoleTypes::SPACE_AUDITOR
          SpaceAuditor
        when RoleTypes::SPACE_SUPPORTER
          SpaceSupporter
        when RoleTypes::SPACE_DEVELOPER
          SpaceDeveloper
        when RoleTypes::SPACE_MANAGER
          SpaceManager
        else
          raise "Invalid role type: #{role}"
        end
      end

      def dataset_from_model_and_filters(model, filters)
        filters.inject(model) do |dataset, filter|
          dataset.where(filter)
        end
      end

      def dataset_with_select(dataset, role)
        ds = dataset.select(Sequel.as(role, :type), Sequel.as(:role_guid, :guid))
        ds = if RoleTypes::ORGANIZATION_ROLES.include?(role)
               ds.select_append(:organization_id, Sequel.as(SPACE_OR_ORGANIZATION_NOT_SPECIFIED, :space_id))
             else
               ds.select_append(Sequel.as(SPACE_OR_ORGANIZATION_NOT_SPECIFIED, :organization_id), :space_id)
             end
        ds.select_append(:user_id, :created_at, :updated_at)
      end

      def datasets_for_individual_roles(filters_per_role)
        RoleTypes::ALL_ROLES.map do |role|
          model = model_by_role(role)
          filters = filters_per_role[role] || []
          dataset = dataset_from_model_and_filters(model, filters)
          dataset_with_select(dataset, role)
        end
      end

      def unioned_dataset(datasets)
        datasets.inject do |dataset, ds|
          dataset.union(ds, all: true, from_self: false)
        end
      end

      def build(filters_per_role={})
        datasets = datasets_for_individual_roles(filters_per_role)
        unioned_dataset(datasets)
      end
    end
  end

  # Sequel allows to create models based on datasets. The following is a dataset that unions all the individual roles
  # tables and labels each row with a `type` column based on which table it came from.
  class Role < Sequel::Model(RoleDataset.build.from_self)
    many_to_one :user, key: :user_id
    many_to_one :organization, key: :organization_id
    many_to_one :space, key: :space_id

    def user_guid
      user.guid
    end

    def organization_guid
      return organization.guid unless organization_id == SPACE_OR_ORGANIZATION_NOT_SPECIFIED

      space.organization_guid
    end

    def space_guid
      space.guid unless space_id == SPACE_OR_ORGANIZATION_NOT_SPECIFIED
    end

    def for_space?
      RoleTypes::SPACE_ROLES.include?(type)
    end

    def model_class
      RoleDataset.model_by_role(type)
    end
  end

  # rubocop:disable Metrics/BlockLength
  Role.dataset_module do
    def first(*cond)
      raise 'Use where(cond).first instead' unless cond.empty?

      super
    end

    # Customized Role model/dataset behavior when filtering:
    # - Replace dataset source with new dataset built with filters per role.
    # - Cache previous filters to supported chained method calls.
    # - Treat invocations with (virtual row) block as before, i.e. apply to overall dataset.
    def where(*cond)
      return super if block_given?

      filters_per_role = self.cache_get(:filters_per_role) || init_filters([])

      Array.wrap(cond).each do |condition|
        filters = case condition
                  when Hash
                    hash_condition_to_filters(condition)
                  when Sequel::SQL::BooleanExpression
                    boolean_expression_to_filters(condition)
                  else
                    raise "Unsupported condition type: #{condition.class}"
                  end

        append_filters(filters_per_role, filters)
      end

      dataset = self.from(RoleDataset.build(filters_per_role))
      dataset.cache_set(:filters_per_role, filters_per_role)
      dataset
    end

    private

    INCLUDE = { 1 => 1 }.freeze
    EXCLUDE = { 1 => 0 }.freeze

    def init_filters(default)
      RoleTypes::ALL_ROLES.each_with_object({}) do |role, filters|
        filters[role] = default.dup
      end
    end

    def append_filters(all_filters, new_filters)
      RoleTypes::ALL_ROLES.each do |role|
        all_filters[role] << new_filters[role]
      end
    end

    def remove_table_name(identifier)
      case identifier
      when String, Symbol
        identifier.to_s.remove(/.*__/).to_sym
      when Sequel::SQL::QualifiedIdentifier
        identifier.column.to_sym
      else
        raise "Unsupported identifier type: #{identifier.class}"
      end
    end

    def adapt_column_name(column_name)
      case column_name
      when :guid
        :role_guid
      else
        column_name
      end
    end

    def adapt_identifier(identifier)
      column_name = remove_table_name(identifier)
      adapt_column_name(column_name)
    end

    def apply_filter_to_roles(all_filters, roles, new_filter)
      roles.each do |role|
        all_filters[role]&.merge!(new_filter)
      end
    end

    def adapt_boolean_expression(expression)
      args = expression.args.map do |arg|
        case arg
        when Sequel::SQL::BooleanExpression
          adapt_boolean_expression(arg)
        when Sequel::SQL::QualifiedIdentifier
          column_name = adapt_identifier(arg)
          raise "Unsupported column: #{column_name}" unless [:created_at, :updated_at].include?(column_name)

          Sequel::SQL::Identifier.new(column_name)
        else
          arg
        end
      end
      Sequel::SQL::BooleanExpression.new(expression.op, *args)
    end

    def hash_condition_to_filters(condition)
      filters = init_filters({})

      condition.transform_keys! { |key| adapt_identifier(key) }

      condition.each do |column_name, filter|
        case column_name
        when :type
          roles = Array.wrap(filter)
          apply_filter_to_roles(filters, roles, INCLUDE)
          apply_filter_to_roles(filters, RoleTypes::ALL_ROLES - roles, EXCLUDE)
        when :organization_id
          apply_filter_to_roles(filters, RoleTypes::ORGANIZATION_ROLES, { organization_id: filter })
          apply_filter_to_roles(filters, RoleTypes::SPACE_ROLES, EXCLUDE)
        when :space_id
          apply_filter_to_roles(filters, RoleTypes::ORGANIZATION_ROLES, EXCLUDE)
          apply_filter_to_roles(filters, RoleTypes::SPACE_ROLES, { space_id: filter })
        when :role_guid, :user_id
          apply_filter_to_roles(filters, RoleTypes::ALL_ROLES, { column_name => filter })
        else
          raise "Unsupported column: #{column_name}"
        end
      end

      filters
    end

    def boolean_expression_to_filters(expression)
      RoleTypes::ALL_ROLES.each_with_object({}) do |role, filters|
        filters[role] = adapt_boolean_expression(expression)
      end
    end
  end
  # rubocop:enable Metrics/BlockLength
end
