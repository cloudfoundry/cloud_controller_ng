Sequel.migration do
  up do
    alter_table :stacks do
      add_column :build_rootfs_image, String, size: 255
      add_column :run_rootfs_image, String, size: 255
    end
  end

  down do
    alter_table :stacks do
      drop_column :build_rootfs_image
      drop_column :run_rootfs_image
    end
  end
end
