def uuid_function(migration)
  if migration.class.name.match?(/mysql/i)
    Sequel.function(:UUID)
  elsif migration.class.name.match?(/postgres/i)
    Sequel.function(:get_uuid)
  end
end
