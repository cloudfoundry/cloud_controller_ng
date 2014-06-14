require "spec_helper"

module VCAP::RestAPI
  describe VCAP::RestAPI::Query, non_transactional: true do
    include VCAP::RestAPI

    class Author < Sequel::Model
      one_to_many :books
    end

    class Book < Sequel::Model
      many_to_one :authors
    end

    before do
      db = Sequel.sqlite(':memory:')
      db.create_table :authors do
        primary_key :id
        String  :str_val
      end

      db.create_table :books do
        primary_key :id
        String  :str_val
        String  :month
        foreign_key :author_id, :authors
      end

      Author.set_dataset(db[:authors])
      Book.set_dataset(db[:books])

      a = Author.create(:str_val => "joe;semi")
      a.add_book(Book.create(:str_val => "two;;semis", :month => "Jan"))
      a.add_book(Book.create(:str_val => "three;;;semis and one;semi",
                             :month => "Jan"))
      a = Author.create(:str_val => "joe/semi")
      a.add_book(Book.create(:str_val => "two;/semis", :month => "Jan"))
      a.add_book(Book.create(:str_val => "x;;semis and one;semi",
                             :month => "Jan"))
      a.add_book(Book.create(:str_val => "x;;/;;semis and one;semi",
                             :month => "Feb"))
      a.add_book(Book.create(:str_val => "x;;;;semis - don't match this",
                             :month => "Feb"))
      a.add_book(Book.create(:str_val => "two;/semis", :month => "Feb"))
      
      @queryable_attributes = Set.new(%w(str_val author_id book_id month))
    end
    
    describe "#filtered_dataset_from_query_params" do
      describe "shared prefix query" do
        it "should return all authors" do
          q = "str_val:joe;;semi"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                        @queryable_attributes, :q => q)
          ds.all.should == [Author[1]]
        end
      end
      
      describe "slash match 1" do
        it "should return the second author" do
          q = "str_val:joe/semi"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                        @queryable_attributes, :q => q)
          ds.all.should == [Author[2]]
        end
      end

      describe "semicolon match on three;;;semis" do
        it "should return book 1-2" do
          q = "str_val:three;;;;;;semis and one;;semi"
          ds = Query.filtered_dataset_from_query_params(Book, Book.dataset,
                                                        @queryable_attributes, :q => q)
          ds.all.should == [Book[2]]
        end
      end

      describe "semicolon match on x;;/" do
        it "should return book 2-2" do
          q = "str_val:x;;;;semis and one;;semi"
          ds = Query.filtered_dataset_from_query_params(Book, Book.dataset,
                                                        @queryable_attributes, :q => q)
          ds.all.should == [Book[4]]
        end
      end

      describe "match two fields" do
        it "should return book 2-3(5)" do
          q = "str_val:x;;;;/;;;;semis and one;;semi;month:Feb"
          ds = Query.filtered_dataset_from_query_params(Book, Book.dataset,
                                                        @queryable_attributes, :q => q)
          ds.all.should == [Book[5]]
        end
      end

    end
  end
end
