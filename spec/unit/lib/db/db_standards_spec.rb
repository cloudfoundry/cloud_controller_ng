require 'spec_helper'

describe 'DB Schema' do
  connection = DbConfig.new.connection

  connection.tables.each do |table|
    it "the table #{table}'s name should not be longer than 60 characters" do
      expect(table.length).to be <= 60
    end

    connection.schema(table).each do |column|
      it "the column #{table}.#{column}'s name should not be longer than 60 characters" do
        expect(column[0].length).to be <= 60
      end
    end if connection.supports_schema_parsing?

    connection.foreign_key_list(table).each do |fk|
      it "the foreign key #{table}.#{fk[:name]}'s name should not be longer than 60 characters" do
        expect(fk[:name].length).to be <= 60
      end unless fk[:name].nil?
    end if connection.supports_foreign_key_parsing?

    connection.indexes(table).each do |name, index|
      it "the index #{table}.#{name}'s name should not be longer than 60 characters" do
        expect(name.length).to be <= 60
      end
    end if connection.supports_index_parsing?
  end if connection.supports_table_listing?
end
