Sequel.migration do
  up do
    drop_table(:domains_spaces)
  end

  down do
    raise Sequel::Error.new('This migration cannot be reversed.')
  end
end
