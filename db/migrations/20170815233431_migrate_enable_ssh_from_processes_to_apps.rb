Sequel.migration do
  change do
    enabled_guids = self[:processes].where(enable_ssh: true, type: 'web').select(:guid)
    disabled_guids = self[:processes].where(enable_ssh: false, type: 'web').select(:guid)
    self[:apps].where(Sequel.lit('guid IN ?', enabled_guids)).update(enable_ssh: true)
    self[:apps].where(Sequel.lit('guid IN ?', disabled_guids)).update(enable_ssh: false)

    # All apps should have a web process.
    # If they don't, these apps will have a nil enable_ssh field which will need to be
    # manually activated.
  end
end
