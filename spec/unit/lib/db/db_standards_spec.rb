require 'spec_helper'

RSpec.describe 'DB Schema' do
  connection = DbConfig.new.connection

  # The maximum length of names for tables, columns and indices is:
  # Postgres: 63bytes -> 63 characters due to UTF-8
  # Mysql: 64 characters
  if connection.supports_table_listing?
    connection.tables.each do |table|
      it "the table #{table}'s name should not be longer than 63 characters" do
        expect(table.length).to be <= 63
      end

      if connection.supports_schema_parsing?
        connection.schema(table).each do |column|
          it "the column #{table}.#{column}'s name should not be longer than 63 characters" do
            expect(column[0].length).to be <= 63
          end
        end
      end

      if connection.supports_foreign_key_parsing?
        connection.foreign_key_list(table).each do |fk|
          next if fk[:name].nil?

          it "the foreign key #{table}.#{fk[:name]}'s name should not be longer than 63 characters" do
            expect(fk[:name].length).to be <= 63
          end
        end
      end

      next unless connection.supports_index_parsing?

      connection.indexes(table).each_key do |name|
        it "the index #{table}.#{name}'s name should not be longer than 63 characters" do
          expect(name.length).to be <= 63
        end
      end
    end
  end
end
