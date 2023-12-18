Sequel.migration do
  up do
    degenerate_records = self[:deployments].where(status_reason: 'DEGENERATE')
    degenerate_records.delete
  end

  down do
    # It is not possible to recover the deleted rows during rollback
  end
end
