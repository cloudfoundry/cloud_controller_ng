Sequel.migration do
  change do
    uuid_function = if self.class.name.match?(/mysql/i)
                      Sequel.function(:UUID)
                    elsif self.class.name.match?(/postgres/i)
                      Sequel.function(:get_uuid)
                    end

    self[:spaces_auditors].
      update(guid: uuid_function, updated_at: Sequel::CURRENT_TIMESTAMP)

    self[:spaces_managers].
      update(guid: uuid_function, updated_at: Sequel::CURRENT_TIMESTAMP)

    self[:spaces_developers].
      update(guid: uuid_function, updated_at: Sequel::CURRENT_TIMESTAMP)

    self[:organizations_users].
      update(guid: uuid_function, updated_at: Sequel::CURRENT_TIMESTAMP)

    self[:organizations_managers].
      update(guid: uuid_function, updated_at: Sequel::CURRENT_TIMESTAMP)

    self[:organizations_auditors].
      update(guid: uuid_function, updated_at: Sequel::CURRENT_TIMESTAMP)

    self[:organizations_billing_managers].
      update(guid: uuid_function, updated_at: Sequel::CURRENT_TIMESTAMP)
  end
end
