Sequel.migration do
  change do
    create_table :lockings do
      primary_key :id
      String :name, null: false, case_insenstive: true
      index :name, unique: true
    end
  end
end
