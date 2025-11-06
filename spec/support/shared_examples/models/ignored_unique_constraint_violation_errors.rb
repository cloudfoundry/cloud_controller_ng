RSpec::Matchers.define :have_primary_key_constraint do |table_name, constraint_name|
  match do |db|
    !db.fetch('SELECT 1 AS one FROM information_schema.table_constraints ' \
              "WHERE constraint_type = 'PRIMARY KEY' " \
              "AND table_name = '#{table_name}' " \
              "AND constraint_name = '#{constraint_name}';").
      get(:one).nil?
  end
end

RSpec.shared_examples 'ignored_unique_constraint_violation_errors' do |association, db|
  it 'ignores unique constraint violation errors in the many_to_many relationship definition' do
    constraint_names = association[:ignored_unique_constraint_violation_errors]
    table_name = association[:join_table]

    constraint_names.each do |constraint_name|
      case constraint_name
      when /_pk$/ # PostgreSQL primary key
        next unless db.database_type == :postgres

        expect(db).to have_primary_key_constraint(table_name, constraint_name)
      when /\.PRIMARY$/ # MySQL primary key
        next unless db.database_type == :mysql

        tn, cn = constraint_name.split('.', 2)
        expect(tn.to_sym).to equal(table_name)
        expect(db).to have_primary_key_constraint(tn, cn)
      else
        expect(db.indexes(table_name)).to include(constraint_name.to_sym)
      end
    end
  end
end
