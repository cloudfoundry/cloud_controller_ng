Sequel.migration do
  change do
    create_table :apps_v3 do
      VCAP::Migration.common(self)
    end
  end
end
