require "spec_helper"

module VCAP::RestAPI
  describe VCAP::RestAPI::Query, non_transactional: true do
    include VCAP::RestAPI

    class AuthorSemiColon < Sequel::Model
      one_to_many :books
    end

    class BookSemiColon < Sequel::Model
      many_to_one :author
    end

    before do
      db.create_table :author_semi_colons do
        primary_key :id
        String  :str_val
      end

      db.create_table :book_semi_colons do
        primary_key :id
        String  :str_val
        String  :month
        foreign_key :author_id, :author_semi_colons
      end

      AuthorSemiColon.set_dataset(db[:author_semi_colons])
      BookSemiColon.set_dataset(db[:book_semi_colons])

      a = AuthorSemiColon.create(:str_val => "joe;semi")
      a.add_book(BookSemiColon.create(:str_val => "two;;semis", :month => "Jan"))
      a.add_book(BookSemiColon.create(:str_val => "three;;;semis and one;semi",
                             :month => "Jan"))
      a = AuthorSemiColon.create(:str_val => "joe/semi")
      a.add_book(BookSemiColon.create(:str_val => "two;/semis", :month => "Jan"))
      a.add_book(BookSemiColon.create(:str_val => "x;;semis and one;semi",
                             :month => "Jan"))
      a.add_book(BookSemiColon.create(:str_val => "x;;/;;semis and one;semi",
                             :month => "Feb"))
      a.add_book(BookSemiColon.create(:str_val => "x;;;;semis - don't match this",
                             :month => "Feb"))
      a.add_book(BookSemiColon.create(:str_val => "two;/semis", :month => "Feb"))
      
      @queryable_attributes = Set.new(%w(str_val author_id book_id month))
    end
    
    describe "#filtered_dataset_from_query_params" do
      describe "shared prefix query" do
        it "should return all authors" do
          q = "str_val:joe*"
          ds = Query.filtered_dataset_from_query_params(AuthorSemiColon, AuthorSemiColon.dataset,
                                                        @queryable_attributes, :q => q)
          ds.count.should == 2
        end
      end
      
      describe "slash match 1" do
        it "should return the second author" do
          q = "str_val:joe/s*"
          ds = Query.filtered_dataset_from_query_params(AuthorSemiColon, AuthorSemiColon.dataset,
                                                        @queryable_attributes, :q => q)
          ds.all.should == [AuthorSemiColon[:str_val => "joe/semi"]]
        end
      end

      describe "semicolon match 1" do
        it "should return the first author" do
          q = "str_val:joe;;s*"
          ds = Query.filtered_dataset_from_query_params(AuthorSemiColon, AuthorSemiColon.dataset,
                                                        @queryable_attributes, :q => q)
          ds.all.should == [AuthorSemiColon[:str_val => "joe;semi"]]
        end
      end

      describe "semicolon match on three;;;semis" do
        it "should return book 1-2" do
          q = "str_val:three;;;;;;semis and one;;s*"
          ds = Query.filtered_dataset_from_query_params(BookSemiColon, BookSemiColon.dataset,
                                                        @queryable_attributes, :q => q)
          ds.all.should == [BookSemiColon[2]]
        end
      end

      describe "semicolon match on x;;/" do
        it "should return book 2-2" do
          q = "str_val:x;;;;s*"
          ds = Query.filtered_dataset_from_query_params(BookSemiColon, BookSemiColon.dataset,
                                                        @queryable_attributes, :q => q)
          ds.all.should == [BookSemiColon[4]]
        end
      end

      describe "match two fields" do
        it "should return book 2-4(6)" do
          q = "str_val:two;;/s*;month:Feb"
          ds = Query.filtered_dataset_from_query_params(BookSemiColon, BookSemiColon.dataset,
                                                        @queryable_attributes, :q => q)
          ds.all.should == [BookSemiColon[7]]
        end
      end

    end
  end
end
