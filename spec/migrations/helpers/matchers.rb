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
