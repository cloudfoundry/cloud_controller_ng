# Copyright (c) 2009-2012 VMware, Inc.
require File.expand_path("../spec_helper", __FILE__)

module VCAP::RestAPI
  describe VCAP::RestAPI::Query do
    include VCAP::RestAPI

    let(:num_authors) { 10 }
    let(:books_per_author) { 2 }

    class Author < Sequel::Model
      one_to_many :books
      ci_attributes :ci_str_val
      vcap_column_alias :alias, :aliased
    end

    class Book < Sequel::Model
      many_to_one :author
    end

    before do
      reset_database

      db.create_table :authors do
        primary_key :id

        Integer :num_val
        String  :str_val
        String  :ci_str_val, :case_insensitive => true
        String  :aliased
        Integer :protected
        TrueClass :published
        DateTime :published_at
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
        # mysql does typecasting of strings to ints, so start values at 0
        # so that the query using string tests don't find the 0 values.
        a = Author.create(:num_val => i + 1,
                          :str_val => "str #{i}",
                          :ci_str_val => i % 2 == 1 ? "ci_str" : "Ci_Str",
                          :aliased => "alias_val",
                          :published => (i == 0),
                          :published_at => (i == 0) ? nil : Time.at(0) + i)
        books_per_author.times do |j|
          a.add_book(Book.create(:num_val => j + 1, :str_val => "str #{i} #{j}"))
        end
      end

      @owner_nil_num = Author.create(:str_val => "no num", :published => false, :published_at => Time.at(0) + num_authors)
      @queryable_attributes = Set.new(%w(num_val str_val ci_str_val alias author_id book_id published published_at))
    end

    describe "#filtered_dataset_from_query_params" do
      describe "no query" do
        it "should return the full dataset" do
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                        @queryable_attributes, {})
          ds.count.should == num_authors
        end
      end

      describe "exact query on a unique integer" do
        it "should return the correct record" do
          q = "num_val:5"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                        @queryable_attributes, :q => q)
          ds.all.should == [Author[:num_val => 5]]
        end
      end

      describe "greater-than comparison query on an integer within the range" do
        it "should return no results" do
          q = "num_val>#{num_authors - 5}"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
            @queryable_attributes, :q => q)

          expected = Author.all.select do |a|
            a.num_val && a.num_val > num_authors - 5
          end

          ds.all.should =~ expected
        end
      end

      describe "greater-than equals comparison query on an integer within the range" do
        it "should return no results" do
          q = "num_val>=#{num_authors - 5}"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
            @queryable_attributes, :q => q)

          expected = Author.all.select do |a|
            a.num_val && a.num_val >= num_authors - 5
          end

          ds.all.should =~ expected
        end
      end

      describe "less-than comparison query on an integer within the range" do
        it "should return no results" do
          q = "num_val<#{num_authors - 5}"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
            @queryable_attributes, :q => q)

          expected = Author.all.select do |a|
            a.num_val && a.num_val < num_authors - 5
          end

          ds.all.should =~ expected
        end
      end

      describe "less-than equals comparison query on an integer within the range" do
        it "should return no results" do
          q = "num_val<=#{num_authors - 5}"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
            @queryable_attributes, :q => q)

          expected = Author.all.select do |a|
            a.num_val && a.num_val <= num_authors - 5
          end

          ds.all.should =~ expected
        end
      end

      describe "exact query on a nonexistent integer" do
        it "should return no results" do
          q = "num_val:#{num_authors + 10}"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
            @queryable_attributes, :q => q)
          ds.count.should == 0
        end
      end

      describe "exact query on an integer field with a string" do
        it "should return no results" do
          q = "num_val:a"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                        @queryable_attributes, :q => q)
          ds.count.should == 0
        end
      end

      describe "exact query on a unique string" do
        it "should return the correct record" do
          q = "str_val:str 5"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                        @queryable_attributes, :q => q)
          ds.all.should == [Author[:str_val => "str 5"]]
        end
      end

      describe "case insensitive query on a unique string" do
        it "should return the correct number of records" do
          q = "ci_str_val:cI_stR"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                        @queryable_attributes, :q => q)
          ds.count.should == num_authors - 1
        end
      end

      describe "exact query on a nonexistent string" do
        it "should return the correct record" do
          q = "str_val:fnord"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                        @queryable_attributes, :q => q)
          ds.count.should == 0
        end
      end

      describe "exact query on a string prefix" do
        it "should return no results" do
          q = "str_val:str"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                        @queryable_attributes, :q => q)
          ds.count.should == 0
        end
      end

      describe "exact query on a nonexistent attribute" do
        it "should raise BadQueryParameter" do
          q = "bogus_val:1"
          expect {
            Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                          @queryable_attributes, :q => q)
          }.to raise_error(VCAP::Errors::BadQueryParameter)
        end
      end

      describe "exact query on a nonallowed attribute" do
        it "should raise BadQueryParameter" do
          q = "protected:1"
          expect {
            Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                          @queryable_attributes, :q => q)
          }.to raise_error(VCAP::Errors::BadQueryParameter)
        end
      end

      describe "querying multiple values" do
        it "should return the correct record" do
          q = "num_val:5;str_val:str 4"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
            @queryable_attributes, :q => q)
          ds.all.should == [Author[:num_val => 5, :str_val => "str 4"]]
        end
      end

      describe "without a key" do
        it "should raise BadQueryParameter" do
          q = ":10"
          expect {
            Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                          @queryable_attributes, :q => q)
          }.to raise_error(VCAP::Errors::BadQueryParameter)
        end
      end

      describe "exact query with nil value" do
        it "should return records with nil entries" do
          q = "num_val:"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                        @queryable_attributes, :q => q)
          ds.all.should == [@owner_nil_num]
        end
      end

      describe "exact query with an nonexistent id from a to_many relation" do
        it "should return no results" do
          q = "book_id:9999"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                        @queryable_attributes, :q => q)
          ds.count.should == 0
        end
      end

      describe "exact query with an id from a to_many relation" do
        it "should return no results" do
          q = "book_id:2"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                        @queryable_attributes, :q => q)
          ds.all.should == [Author[Book[2].author_id]]
        end
      end

      describe "exact query with an nonexistent id from a to_one relation" do
        it "should return no results" do
          q = "author_id:9999"
          ds = Query.filtered_dataset_from_query_params(Book, Book.dataset,
                                                        @queryable_attributes, :q => q)
          ds.count.should == 0
        end
      end

      describe "exact query with an id from a to_one relation" do
        it "should return the correct results" do
          q = "author_id:1"
          ds = Query.filtered_dataset_from_query_params(Book, Book.dataset,
                                                        @queryable_attributes, :q => q)
          ds.all.should == Author[1].books
        end
      end

      describe "boolean values on boolean column" do
        it "returns correctly filtered results for true" do
          ds = Query.filtered_dataset_from_query_params(
            Author, Author.dataset, @queryable_attributes, :q => "published:t")
          ds.all.should == [Author.first]
        end

        it "returns correctly filtered results for false" do
          ds = Query.filtered_dataset_from_query_params(
            Author, Author.dataset, @queryable_attributes, :q => "published:f")
          ds.all.should == Author.all - [Author.first]
        end
      end

      describe "exact query on a timestamp" do
        context "when the timestamp is null" do
          it "should return the correct record" do
            q = "published_at:"
            ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
              @queryable_attributes, :q => q)
            ds.all.should == [Author[:num_val => 1]]
          end
        end

        context "when the timestamp is valid" do
          it "should return the correct record" do
            query_value = Author[:num_val => 5].published_at
            q = "published_at:#{query_value}"
            ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
              @queryable_attributes, :q => q)
            ds.all.should == [Author[:num_val => 5]]
          end
        end
      end

      describe "greater-than comparison query on a timestamp within the range" do
        it "should return 5 records" do
          query_value = Author[:num_val => 5].published_at
          q = "published_at>#{query_value}"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
            @queryable_attributes, :q => q)

          expected = Author.all.select do |a|
            a.published_at && a.published_at > query_value
          end

          ds.all.should =~ expected
        end
      end

      describe "greater-than equals comparison query on a timestamp within the range" do
        it "should return 6 records" do
          query_value = Author[:num_val => 5].published_at
          q = "published_at>=#{query_value}"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
            @queryable_attributes, :q => q)

          expected = Author.all.select do |a|
            a.published_at && a.published_at >= query_value
          end

          ds.all.should =~ expected
        end
      end

      describe "less-than comparison query on a timestamp within the range" do
        it "should return 3 records" do
          query_value = Author[:num_val => 5].published_at
          q = "published_at<#{query_value}"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
            @queryable_attributes, :q => q)

          expected = Author.all.select do |a|
            a.published_at && a.published_at < query_value
          end

          ds.all.should =~ expected
        end
      end

      describe "less-than equals comparison query on a timestamp within the range" do
        it "should returns 4 records" do
          query_value = Author[:num_val => 5].published_at
          q = "published_at<=#{query_value}"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
            @queryable_attributes, :q => q)

          expected = Author.all.select do |a|
            a.published_at && a.published_at <= query_value
          end

          ds.all.should =~ expected
        end
      end

      describe "exact query on a invalid timestamp" do
        it "should return no results" do
          query_value = Author.all.last.published_at + 1
          q = "published_at:#{query_value}"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
            @queryable_attributes, :q => q)

          ds.count.should == 0
        end
      end

      describe "exact query on a malformed timestamp" do
        it "should raise argument error" do
          q = "published_at:asdf"

          expect { Query.filtered_dataset_from_query_params(Author, Author.dataset,
            @queryable_attributes, :q => q) }.to raise_error(ArgumentError)
        end
      end

      describe "aliased column" do
        it "should convert the alias param to db column" do
          ds = Query.filtered_dataset_from_query_params(
            Author, Author.dataset, @queryable_attributes, :q => "alias:alias_val")
          ds.count.should > 0
        end
        it "should fail if querying with the column name" do
          expect {
            ds = Query.filtered_dataset_from_query_params(
              Author, Author.dataset, @queryable_attributes, :q => "aliased:alias_val")
          }.to raise_error(VCAP::Errors::BadQueryParameter)
        end
      end
    end
  end
end
