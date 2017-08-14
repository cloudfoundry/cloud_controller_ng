Sequel.migration do
  up do
    drop_table(:billing_events, :service_auth_tokens)
  end

  down do
    # this migration is not reversible
  end
end
