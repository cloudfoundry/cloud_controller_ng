# Copyright (c) 2009-2012 VMware, Inc.
require File.expand_path("../spec_helper", __FILE__)

describe "VCAP::RestAPI::Query" do
  include VCAP::RestAPI

  num_authors = 10
  books_per_author = 2

  class Author < Sequel::Model
    one_to_many :books
  end

  class Book < Sequel::Model
    many_to_one :author
  end

  before do
    db = Sequel.sqlite

    db.create_table :authors do
      primary_key :id

      Integer :num_val
      String  :str_val
      Integer :protected
    end

    db.create_table :books do
      primary_key :id

      Integer :num_val
      String  :str_val

      foreign_key :author_id, :authors
    end

    Author.set_dataset(db[:authors])
    Book.set_dataset(db[:books])

    (num_authors - 1).times do |i|
      a = Author.create(:num_val => i, :str_val => "str #{i}")
      books_per_author.times do |j|
        a.add_book(Book.create(:num_val => j, :str_val => "str #{i} #{j}"))
      end
    end

    @owner_nil_num = Author.create(:str_val => "no num")
    @queryable_attributes = Set.new(["num_val", "str_val",
                                     "author_id", "book_id"])
  end

  describe "#dataset_from_query_params" do
    let(:access_filter) { {} }

    describe "no query" do
      it "should return the full dataset" do
        ds = Query.dataset_from_query_params(Author, access_filter,
                                             @queryable_attributes, {})
        ds.count.should == num_authors
      end
    end

    describe "exact query on a unique integer" do
      it "should return the correct record" do
        q = "num_val:5"
        ds = Query.dataset_from_query_params(Author, access_filter,
                                             @queryable_attributes, :q => q)
        ds.all.should == [Author[:num_val => 5]]
      end
    end

    describe "exact query on a nonexistent integer" do
      it "should return no results" do
        q = "num_val:#{num_authors + 10}"
        ds = Query.dataset_from_query_params(Author, access_filter,
                                             @queryable_attributes, :q => q)
        ds.count.should == 0
      end
    end

    describe "exact query on an integer field with a string" do
      it "should return no results" do
        q = "num_val:a"
        ds = Query.dataset_from_query_params(Author, access_filter,
                                             @queryable_attributes, :q => q)
        ds.count.should == 0
      end
    end

    describe "exact query on a unique string" do
      it "should return the correct record" do
        q = "str_val:str 5"
        ds = Query.dataset_from_query_params(Author, access_filter,
                                             @queryable_attributes, :q => q)
        ds.all.should == [Author[:str_val => "str 5"]]
      end
    end

    describe "exact query on a nonexistent string" do
      it "should return the correct record" do
        q = "str_val:fnord"
        ds = Query.dataset_from_query_params(Author, access_filter,
                                             @queryable_attributes, :q => q)
        ds.count.should == 0
      end
    end

    describe "exact query on a string prefix" do
      it "should return no results" do
        q = "str_val:str"
        ds = Query.dataset_from_query_params(Author, access_filter,
                                             @queryable_attributes, :q => q)
        ds.count.should == 0
      end
    end

    describe "exact query on a nonexistent attribute" do
      it "should raise BadQueryParameter" do
        q = "bogus_val:1"
        lambda {
          ds = Query.dataset_from_query_params(Author, access_filter,
                                               @queryable_attributes, :q => q)
        }.should raise_error(VCAP::RestAPI::Errors::BadQueryParameter)
      end
    end

    describe "exact query on a nonallowed attribute" do
      it "should raise BadQueryParameter" do
        q = "protected:1"
        lambda {
          ds = Query.dataset_from_query_params(Author, access_filter,
                                               @queryable_attributes, :q => q)
        }.should raise_error(VCAP::RestAPI::Errors::BadQueryParameter)
      end
    end

    describe "without a key" do
      it "should raise BadQueryParameter" do
        q = ":10"
        lambda {
          ds = Query.dataset_from_query_params(Author, access_filter,
                                               @queryable_attributes, :q => q)
        }.should raise_error(VCAP::RestAPI::Errors::BadQueryParameter)
      end
    end

    describe "with an extra :" do
      it "should raise BadQueryParameter" do
        q = "num_val:1:0"
        lambda {
          ds = Query.dataset_from_query_params(Author, access_filter,
                                               @queryable_attributes, :q => q)
        }.should raise_error(VCAP::RestAPI::Errors::BadQueryParameter)
      end
    end

    describe "exact query with nil value" do
      it "should return records with nil entries" do
        q = "num_val:"
        ds = Query.dataset_from_query_params(Author, access_filter,
                                             @queryable_attributes, :q => q)
        ds.all.should == [@owner_nil_num]
      end
    end

    describe "exact query with an nonexistent id from a to_many relation" do
      it "should return no results" do
        q = "book_id:9999"
        ds = Query.dataset_from_query_params(Author, access_filter,
                                             @queryable_attributes, :q => q)
        ds.count.should == 0
      end
    end

    describe "exact query with an id from a to_many relation" do
      it "should return no results" do
        q = "book_id:2"
        ds = Query.dataset_from_query_params(Author, access_filter,
                                             @queryable_attributes, :q => q)
        ds.all.should == [Author[Book[2].author_id]]
      end
    end

    describe "exact query with an nonexistent id from a to_one relation" do
      it "should return no results" do
        q = "author_id:9999"
        ds = Query.dataset_from_query_params(Book, access_filter,
                                             @queryable_attributes, :q => q)
        ds.count.should == 0
      end
    end

    describe "exact query with an id from a to_one relation" do
      it "should return the correct results" do
        q = "author_id:1"
        ds = Query.dataset_from_query_params(Book, access_filter,
                                             @queryable_attributes, :q => q)
        ds.all.should == Author[1].books
      end
    end
  end
end
