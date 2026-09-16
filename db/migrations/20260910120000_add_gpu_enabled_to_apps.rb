Sequel.migration do
  up do
    if database_type == :postgres
      add_column :apps, :gpu_enabled, :boolean, default: false, null: false, if_not_exists: true
    else
      # MySQL
      add_column :apps, :gpu_enabled, :boolean, default: false, null: false unless schema(:apps).map(&:first).include?(:gpu_enabled)
    end
  end

  down do
    if database_type == :postgres
      drop_column :apps, :gpu_enabled, if_exists: true
    elsif schema(:apps).map(&:first).include?(:gpu_enabled)
      drop_column :apps, :gpu_enabled
    end
  end
end
