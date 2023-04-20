module Sequel::UniqueColumnSubquery
  def requires_unique_column_names_in_subquery_select_list?
    unless Sequel::UniqueColumnSubquery.const_defined?(:UNIQUE_NAMES_IN_SUBQUERY)
      Sequel::UniqueColumnSubquery.const_set(:UNIQUE_NAMES_IN_SUBQUERY, unique_names_in_subquery?)
    end

    Sequel::UniqueColumnSubquery.const_get(:UNIQUE_NAMES_IN_SUBQUERY)
  end

  private

  def unique_names_in_subquery?
    self.db.fetch('SELECT * FROM (SELECT 1 AS a, 1 AS a) AS t1').all
    false
  rescue Sequel::DatabaseError
    true
  end
end

Sequel::Dataset.register_extension(:requires_unique_column_names_in_subquery, Sequel::UniqueColumnSubquery)
