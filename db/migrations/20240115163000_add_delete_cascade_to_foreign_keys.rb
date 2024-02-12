require File.expand_path('../helpers/add_delete_cascade_to_foreign_key', __dir__)

Sequel.migration do
  foreign_keys = [
    ForeignKey.new(:deployment_processes, :fk_deployment_processes_deployment_guid, :deployment_guid, :deployments, :guid),
    ForeignKey.new(:deployment_labels, :fk_deployment_labels_resource_guid, :resource_guid, :deployments, :guid),
    ForeignKey.new(:deployment_annotations, :fk_deployment_annotations_resource_guid, :resource_guid, :deployments, :guid),
    ForeignKey.new(:build_labels, :fk_build_labels_resource_guid, :resource_guid, :builds, :guid),
    ForeignKey.new(:build_annotations, :fk_build_annotations_resource_guid, :resource_guid, :builds, :guid),
    ForeignKey.new(:kpack_lifecycle_data, :fk_kpack_lifecycle_build_guid, :build_guid, :builds, :guid),
    ForeignKey.new(:buildpack_lifecycle_data, :fk_buildpack_lifecycle_build_guid, :build_guid, :builds, :guid, new_constraint: true),
    ForeignKey.new(:buildpack_lifecycle_buildpacks, :fk_blbuildpack_bldata_guid, :buildpack_lifecycle_data_guid, :buildpack_lifecycle_data, :guid),
    ForeignKey.new(:task_labels, :fk_task_labels_resource_guid, :resource_guid, :tasks, :guid),
    ForeignKey.new(:task_annotations, :fk_task_annotations_resource_guid, :resource_guid, :tasks, :guid),
    ForeignKey.new(:revision_labels, :fk_revision_labels_resource_guid, :resource_guid, :revisions, :guid),
    ForeignKey.new(:revision_annotations, :fk_revision_annotations_resource_guid, :resource_guid, :revisions, :guid),
    ForeignKey.new(:revision_process_commands, :rev_commands_revision_guid_fkey, :revision_guid, :revisions, :guid),
    ForeignKey.new(:revision_sidecars, :fk_sidecar_revision_guid, :revision_guid, :revisions, :guid),
    ForeignKey.new(:revision_sidecar_process_types, :fk_revision_sidecar_proc_type_sidecar_guid, :revision_sidecar_guid, :revision_sidecars, :guid),
    ForeignKey.new(:sidecar_process_types, :fk_sidecar_proc_type_sidecar_guid, :sidecar_guid, :sidecars, :guid)
  ]

  no_transaction

  up do
    db = self

    foreign_keys.each do |fk|
      transaction { recreate_foreign_key_with_delete_cascade(db, fk) }
    end
  end

  down do
    db = self

    foreign_keys.each do |fk|
      transaction { recreate_foreign_key_without_delete_cascade(db, fk) }
    end
  end
end
