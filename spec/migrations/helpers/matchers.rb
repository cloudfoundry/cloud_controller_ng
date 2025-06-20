RSpec::Matchers.define :add_index_options do
  description { 'options for add_index' }

  match do |passed_options|
    options = passed_options.keys
    !options.delete(:name).nil? && (options - %i[where if_not_exists concurrently]).empty?
  end
end

RSpec::Matchers.define :drop_index_options do
  description { 'options for drop_index' }

  match do |passed_options|
    options = passed_options.keys
    !options.delete(:name).nil? && (options - %i[if_exists concurrently]).empty?
  end
end

RSpec::Matchers.define :have_table_with_column do |table, column|
  match do |db|
    db[table].columns.include?(column)
  end
end

RSpec::Matchers.define :have_table_with_column_and_type do |table, column, type|
  match do |db|
    expect(db).to have_table_with_column(table, column)

    db.schema(table).find { |col, _| col == column }&.dig(1, :db_type) == type
  end
end

RSpec::Matchers.define :have_trigger_function_for_table do |table|
  match do |db|
    function_name = :"#{table}_set_id_bigint_on_insert"
    trigger_name = :"trigger_#{function_name}"

    function_exists = false
    db.fetch("SELECT * FROM information_schema.routines WHERE routine_name = '#{function_name}';") do
      function_exists = true
    end

    trigger_exists = false
    db.fetch("SELECT * FROM information_schema.triggers WHERE trigger_name = '#{trigger_name}';") do
      trigger_exists = true
    end

    raise 'either function and trigger must exist or none of them' if function_exists != trigger_exists

    trigger_exists
  end
end

RSpec::Matchers.define :have_table_with_unpopulated_column do |table, column|
  match do |db|
    db[table].where(column => nil).any?
  end
end
