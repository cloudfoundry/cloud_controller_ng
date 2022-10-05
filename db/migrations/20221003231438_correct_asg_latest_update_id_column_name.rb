Sequel.migration do
  change do
    alter_table :asg_timestamps do
      rename_column :'{:name=>:id}', :id
    end
  end
end
