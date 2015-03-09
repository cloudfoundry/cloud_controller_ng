Sequel.migration do
  up do
    if self.class.name.match /mysql/i
      alter_table :delayed_jobs do
        set_column_type :handler, :longtext
      end
    end
  end

  down do
    if self.class.name.match /mysql/i
      alter_table :delayed_jobs do
        set_column_type :handler, String, text: true
      end
    end
  end
end
