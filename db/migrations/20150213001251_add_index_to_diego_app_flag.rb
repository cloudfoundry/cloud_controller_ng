Sequel.migration do
  up do
    add_index :apps, :diego
  end

  down do
    drop_index :apps, :diego
  end
end
