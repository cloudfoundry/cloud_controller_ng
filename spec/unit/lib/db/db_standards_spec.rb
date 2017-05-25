require 'spec_helper'

RSpec.describe 'DB Schema' do
  connection = DbConfig.new.connection

  if connection.supports_table_listing?
    connection.tables.each do |table|
      it "the table #{table}'s name should not be longer than 60 characters" do
        expect(table.length).to be <= 60
      end

      if connection.supports_schema_parsing?
        connection.schema(table).each do |column|
          it "the column #{table}.#{column}'s name should not be longer than 60 characters" do
            expect(column[0].length).to be <= 60
          end
        end
      end

      if connection.supports_foreign_key_parsing?
        connection.foreign_key_list(table).each do |fk|
          unless fk[:name].nil?
            it "the foreign key #{table}.#{fk[:name]}'s name should not be longer than 60 characters" do
              expect(fk[:name].length).to be <= 60
            end
          end
        end
      end

      if connection.supports_index_parsing?
        connection.indexes(table).each do |name, index|
          it "the index #{table}.#{name}'s name should not be longer than 60 characters" do
            expect(name.length).to be <= 60
          end
        end
      end
    end
  end
end
