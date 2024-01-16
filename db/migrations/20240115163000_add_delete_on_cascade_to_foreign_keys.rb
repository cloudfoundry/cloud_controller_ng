Sequel.migration do
  # Add DELETE CASCADE to foreign keys.

  up do
    alter_table :deployment_processes do
      drop_constraint :fk_deployment_processes_deployment_guid, type: :foreign_key
      add_foreign_key [:deployment_guid], :deployments, key: :guid, name: :fk_deployment_processes_deployment_guid, on_delete: :cascade
    end

    alter_table :deployment_labels do
      drop_constraint :fk_deployment_labels_resource_guid, type: :foreign_key
      add_foreign_key [:resource_guid], :deployments, key: :guid, name: :fk_deployment_labels_resource_guid, on_delete: :cascade
    end

    alter_table :deployment_annotations do
      drop_constraint :fk_deployment_annotations_resource_guid, type: :foreign_key
      add_foreign_key [:resource_guid], :deployments, key: :guid, name: :fk_deployment_annotations_resource_guid, on_delete: :cascade
    end

    alter_table :build_labels do
      drop_constraint :fk_build_labels_resource_guid, type: :foreign_key
      add_foreign_key [:resource_guid], :builds, key: :guid, name: :fk_build_labels_resource_guid, on_delete: :cascade
    end

    alter_table :build_annotations do
      drop_constraint :fk_build_annotations_resource_guid, type: :foreign_key
      add_foreign_key [:resource_guid], :builds, key: :guid, name: :fk_build_annotations_resource_guid, on_delete: :cascade
    end

    alter_table :kpack_lifecycle_data do
      drop_constraint :fk_kpack_lifecycle_build_guid, type: :foreign_key
      add_foreign_key [:build_guid], :builds, key: :guid, name: :fk_kpack_lifecycle_build_guid, on_delete: :cascade
    end

    alter_table :buildpack_lifecycle_data do
      add_foreign_key [:build_guid], :builds, key: :guid, name: :fk_buildpack_lifecycle_build_guid, on_delete: :cascade
    end

    alter_table :buildpack_lifecycle_buildpacks do
      drop_constraint :fk_blbuildpack_bldata_guid, type: :foreign_key
      add_foreign_key [:buildpack_lifecycle_data_guid], :buildpack_lifecycle_data, key: :guid, name: :fk_blbuildpack_bldata_guid, on_delete: :cascade
    end

    alter_table :task_labels do
      drop_constraint :fk_task_labels_resource_guid, type: :foreign_key
      add_foreign_key [:resource_guid], :tasks, key: :guid, name: :fk_task_labels_resource_guid, on_delete: :cascade
    end

    alter_table :task_annotations do
      drop_constraint :fk_task_annotations_resource_guid, type: :foreign_key
      add_foreign_key [:resource_guid], :tasks, key: :guid, name: :fk_task_annotations_resource_guid, on_delete: :cascade
    end

    alter_table :revision_labels do
      drop_constraint :fk_revision_labels_resource_guid, type: :foreign_key
      add_foreign_key [:resource_guid], :revisions, key: :guid, name: :fk_revision_labels_resource_guid, on_delete: :cascade
    end

    alter_table :revision_annotations do
      drop_constraint :fk_revision_annotations_resource_guid, type: :foreign_key
      add_foreign_key [:resource_guid], :revisions, key: :guid, name: :fk_revision_annotations_resource_guid, on_delete: :cascade
    end

    alter_table :revision_process_commands do
      drop_constraint :rev_commands_revision_guid_fkey, type: :foreign_key
      add_foreign_key [:revision_guid], :revisions, key: :guid, name: :rev_commands_revision_guid_fkey, on_delete: :cascade
    end

    alter_table :revision_sidecars do
      drop_constraint :fk_sidecar_revision_guid, type: :foreign_key
      add_foreign_key [:revision_guid], :revisions, key: :guid, name: :fk_sidecar_revision_guid, on_delete: :cascade
    end

    alter_table :revision_sidecar_process_types do
      drop_constraint :fk_revision_sidecar_proc_type_sidecar_guid, type: :foreign_key
      add_foreign_key [:revision_sidecar_guid], :revision_sidecars, key: :guid, name: :fk_revision_sidecar_proc_type_sidecar_guid, on_delete: :cascade
    end

    alter_table :sidecar_process_types do
      drop_constraint :fk_sidecar_proc_type_sidecar_guid, type: :foreign_key
      add_foreign_key [:sidecar_guid], :sidecars, key: :guid, name: :fk_sidecar_proc_type_sidecar_guid, on_delete: :cascade
    end
  end

  down do
    alter_table :deployment_processes do
      drop_constraint :fk_deployment_processes_deployment_guid, type: :foreign_key
      add_foreign_key [:deployment_guid], :deployments, key: :guid, name: :fk_deployment_processes_deployment_guid
    end

    alter_table :deployment_labels do
      drop_constraint :fk_deployment_labels_resource_guid, type: :foreign_key
      add_foreign_key [:resource_guid], :deployments, key: :guid, name: :fk_deployment_labels_resource_guid
    end

    alter_table :deployment_annotations do
      drop_constraint :fk_deployment_annotations_resource_guid, type: :foreign_key
      add_foreign_key [:resource_guid], :deployments, key: :guid, name: :fk_deployment_annotations_resource_guid
    end

    alter_table :build_labels do
      drop_constraint :fk_build_labels_resource_guid, type: :foreign_key
      add_foreign_key [:resource_guid], :builds, key: :guid, name: :fk_build_labels_resource_guid
    end

    alter_table :build_annotations do
      drop_constraint :fk_build_annotations_resource_guid, type: :foreign_key
      add_foreign_key [:resource_guid], :builds, key: :guid, name: :fk_build_annotations_resource_guid
    end

    alter_table :kpack_lifecycle_data do
      drop_constraint :fk_kpack_lifecycle_build_guid, type: :foreign_key
      add_foreign_key [:build_guid], :builds, key: :guid, name: :fk_kpack_lifecycle_build_guid
    end

    alter_table :buildpack_lifecycle_data do
      drop_constraint :fk_buildpack_lifecycle_build_guid, type: :foreign_key
    end

    alter_table :buildpack_lifecycle_buildpacks do
      drop_constraint :fk_blbuildpack_bldata_guid, type: :foreign_key
      add_foreign_key [:buildpack_lifecycle_data_guid], :buildpack_lifecycle_data, key: :guid, name: :fk_blbuildpack_bldata_guid
    end

    alter_table :task_labels do
      drop_constraint :fk_task_labels_resource_guid, type: :foreign_key
      add_foreign_key [:resource_guid], :tasks, key: :guid, name: :fk_task_labels_resource_guid
    end

    alter_table :task_annotations do
      drop_constraint :fk_task_annotations_resource_guid, type: :foreign_key
      add_foreign_key [:resource_guid], :tasks, key: :guid, name: :fk_task_annotations_resource_guid
    end

    alter_table :revision_labels do
      drop_constraint :fk_revision_labels_resource_guid, type: :foreign_key
      add_foreign_key [:resource_guid], :revisions, key: :guid, name: :fk_revision_labels_resource_guid
    end

    alter_table :revision_annotations do
      drop_constraint :fk_revision_annotations_resource_guid, type: :foreign_key
      add_foreign_key [:resource_guid], :revisions, key: :guid, name: :fk_revision_annotations_resource_guid
    end

    alter_table :revision_process_commands do
      drop_constraint :rev_commands_revision_guid_fkey, type: :foreign_key
      add_foreign_key [:revision_guid], :revisions, key: :guid, name: :rev_commands_revision_guid_fkey
    end

    alter_table :revision_sidecars do
      drop_constraint :fk_sidecar_revision_guid, type: :foreign_key
      add_foreign_key [:revision_guid], :revisions, key: :guid, name: :fk_sidecar_revision_guid
    end

    alter_table :revision_sidecar_process_types do
      drop_constraint :fk_revision_sidecar_proc_type_sidecar_guid, type: :foreign_key
      add_foreign_key [:revision_sidecar_guid], :revision_sidecars, key: :guid, name: :fk_revision_sidecar_proc_type_sidecar_guid
    end

    alter_table :sidecar_process_types do
      drop_constraint :fk_sidecar_proc_type_sidecar_guid, type: :foreign_key
      add_foreign_key [:sidecar_guid], :sidecars, key: :guid, name: :fk_sidecar_proc_type_sidecar_guid
    end
  end
end
