Sequel.migration do
  up do
    degenerate_records = self[:deployments].where(status_reason: 'DEGENERATE')

    if degenerate_records.count > 0
      guids_dataset = degenerate_records.select(:guid)
      self[:deployment_processes].where(deployment_guid: guids_dataset).delete
      self[:deployment_labels].where(resource_guid: guids_dataset).delete
      self[:deployment_annotations].where(resource_guid: guids_dataset).delete
      degenerate_records.delete
    end
  end

  down do
    # It is not possible to recover the deleted rows during rollback
  end
end
