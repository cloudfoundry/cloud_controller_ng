module Sequel::UniqueColumnSubquery
  def requires_unique_column_names_in_subquery_select_list?
    begin
      self.db.fetch('SELECT * FROM (SELECT 1 AS a, 1 AS a) AS t1').all
      unique_names_in_subquery = false
    rescue Sequel::DatabaseError
      unique_names_in_subquery = true
    end

    unique_names_in_subquery
  end
end

Sequel::Dataset.register_extension(:requires_unique_column_names_in_subquery, Sequel::UniqueColumnSubquery)
