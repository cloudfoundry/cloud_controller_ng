Sequel.migration do
  change do
    add_column :apps, :command, String, size: 4096
  end
end
