require "spec_helper"

describe "DB Schema" do
  context "To support Oracle" do
    DbConfig.connection.tables.each do |table|
      
      it "the table #{table}'s name should not be longer than 30 characters" do
        expect(table.length).to be <= 30
      end
      
      DbConfig.connection.schema(table).each do |column|
        it "the column #{table}.#{column}'s name should not be longer than 30 characters" do          
          expect(column[0].length).to be <= 30
        end
      end if DbConfig.connection.supports_schema_parsing?

      DbConfig.connection.foreign_key_list(table).each do |fk|
        it "the foreign key #{table}.#{fk[:name]}'s name should not be longer than 30 characters" do
          expect(fk[:name].length).to be <= 30
        end unless fk[:name].nil?
      end if DbConfig.connection.supports_foreign_key_parsing?

      DbConfig.connection.indexes(table).each do |name,index|
        it "the index #{table}.#{name}'s name should not be longer than 30 characters" do
          expect(name.length).to be <= 30
        end
      end if DbConfig.connection.supports_index_parsing?
    end if DbConfig.connection.supports_table_listing?
  end 
end
