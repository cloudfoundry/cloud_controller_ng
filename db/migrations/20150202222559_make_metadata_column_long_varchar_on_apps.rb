Sequel.migration do
  Sequel.migration do
    up do
      alter_table :apps do
        set_column_type :metadata, String, size: 4096
        set_column_default :metadata, '{}'
      end
    end

    down do
      alter_table :apps do
        set_column_type :metadata, String, text: true
      end
    end
  end
end
