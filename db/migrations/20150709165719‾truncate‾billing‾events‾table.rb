Sequel.migration do
  change do
    self[:billing_events].truncate
  end
end
