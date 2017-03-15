Sequel.migration do
  up do
    alter_table(:events) do
      drop_column(:space_id, :if_exists => true)
    end
  end

  down do
    raise Sequel::Error.new('This migration cannot be reversed.')
  end
end
