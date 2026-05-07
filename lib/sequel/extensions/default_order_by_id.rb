# frozen_string_literal: true

# Sequel extension that adds default ORDER BY id to model queries.
#
# Hooks into fetch methods (all, each, first) and placeholder_literalizer_loader
# (used for optimized association loading) to add ORDER BY id just before
# execution. This ensures ordering is only added to the final query, not to
# subqueries or compound query parts.
#
# Skips default ordering when:
# - Query already has explicit ORDER BY
# - Query is incompatible (GROUP BY, compounds, DISTINCT ON, from_self)
# - Query is schema introspection (LIMIT 0)
# - Model doesn't have id as primary key
# - id is not in the select list
#
# For JOIN queries with SELECT *, uses qualified column (table.id) to avoid
# ambiguity.
#
# Ensures deterministic query results for consistent API responses and
# reliable test behavior.
#
# Usage:
#   DB.extension(:sql_comments)
#   DB.extension(:default_order_by_id)
#
module Sequel
  module DefaultOrderById
    module DatasetMethods
      def all(*, &)
        ds = default_order_by_id
        return super unless ds

        ds.all(*, &)
      end

      def each(*, &)
        ds = default_order_by_id
        return super unless ds

        ds.each(*, &)
      end

      def first(*, &)
        ds = default_order_by_id
        return super unless ds

        ds.first(*, &)
      end

      def placeholder_literalizer_loader(&block)
        super do |pl, ds|
          result_ds = block.call(pl, ds)
          result_ds.send(:default_order_by_id) || result_ds
        end
      end

      private

      def default_order_by_id
        id_col = id_column_for_order
        return unless id_col

        order(id_col).comment('default_order_by_id')
      end

      def id_column_for_order
        return if already_ordered? || incompatible_with_order? || not_a_data_query? || !model_has_id_primary_key?

        find_id_column
      end

      def already_ordered?
        opts[:order]
      end

      def incompatible_with_order?
        opts[:group] ||       # Aggregated results don't have individual ids
          opts[:compounds] || # Compound queries (e.g. UNION) have own ordering
          distinct_on? ||     # DISTINCT ON requires matching ORDER BY
          from_self?          # Outer query handles ordering
      end

      def distinct_on?
        opts[:distinct].is_a?(Array) && opts[:distinct].any?
      end

      def from_self?
        opts[:from].is_a?(Array) && opts[:from].any? { |f| f.is_a?(Sequel::SQL::AliasedExpression) && f.expression.is_a?(Sequel::Dataset) }
      end

      def not_a_data_query?
        opts[:limit] == 0 # Schema introspection query
      end

      def model_has_id_primary_key?
        return false unless respond_to?(:model) && model

        model.primary_key == :id
      end

      def find_id_column
        select_cols = opts[:select]

        if select_cols.nil? || select_cols.empty?
          # SELECT * includes id
          if opts[:join]
            # Qualify to avoid ambiguity with joined tables
            return Sequel.qualify(model.table_name, :id)
          end

          return :id
        end

        select_cols.each do |col|
          # SELECT table.* includes id
          return :id if col.is_a?(Sequel::SQL::ColumnAll) && col.table == model.table_name

          id_col = extract_id_column(col)
          return id_col if id_col
        end

        nil
      end

      def extract_id_column(col)
        return col if id_expression?(col)

        return col.alias if col.is_a?(Sequel::SQL::AliasedExpression) && id_expression?(col.expression)

        nil
      end

      def id_expression?(expr)
        case expr
        when Symbol
          expr == :id || expr.to_s.end_with?('__id')
        when Sequel::SQL::Identifier
          expr.value == :id
        when Sequel::SQL::QualifiedIdentifier
          expr.column == :id
        else
          false
        end
      end
    end
  end

  Dataset.register_extension(:default_order_by_id, DefaultOrderById::DatasetMethods)
end
