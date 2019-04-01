Sequel.migration do
  up do
    if database_type == :postgres
      run <<-SQL
        ALTER TABLE events DROP COLUMN IF EXISTS space_id;
      SQL
    elsif dataset.db['select * from information_schema.columns where table_name = \'events\' and column_name = \'space_id\''].any?
      alter_table(:events) do
        drop_column(:space_id)
      end
    end
  end

  down do
    raise Sequel::Error.new('This migration cannot be reversed.')
  end
end
