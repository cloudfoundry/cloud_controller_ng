Sequel.migration do
  change do
    transaction do
      # remove orphaned apps
      run 'DELETE FROM apps WHERE space_guid NOT IN (SELECT guid FROM spaces)'
    end
  end
end
