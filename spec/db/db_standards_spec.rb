require "spec_helper"

describe "For the DB schema" do
  context "to support Oracle" do
    $spec_env.db.tables.each do |table|
      
      it "the table #{table}'s name should not be longer than 30 characters" do
        table.length.should <= 30
      end
      
      $spec_env.db.schema(table).each do |column|
        it "the column #{table}.#{column[0]}'s name should not be longer than 30 characters" do          
          column[0].length.should <= 30
        end
        
        it "the column #{table}.#{column[0]} cannot be named 'timestamp'" do
          column[0].should_not eq(:timestamp)
        end
        
      end if $spec_env.db.supports_schema_parsing?

      $spec_env.db.foreign_key_list(table).each do |fk|
        it "the foreign key #{table}.#{fk[:name]}'s name should not be longer than 30 characters" do
          fk[:name].length.should <= 30
        end unless fk[:name].nil?
      end if $spec_env.db.supports_foreign_key_parsing?

      $spec_env.db.indexes(table).each do |name,index|
        it "the index #{table}.#{name}'s name should not be longer than 30 characters" do
          name.length.should <= 30
        end
      end if $spec_env.db.supports_index_parsing?
    end if $spec_env.db.supports_table_listing? 
  end 
end