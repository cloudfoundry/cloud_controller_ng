require 'spec_helper'

module VCAP::RestAPI
  describe VCAP::RestAPI::Query do
    include VCAP::RestAPI

    class Author < Sequel::Model
      one_to_many :books
    end

    class Book < Sequel::Model
      many_to_one :author
    end

    class Magazine < Sequel::Model
      one_to_many :subscribers
    end

    class Subscriber < Sequel::Model
      many_to_one :magazine
    end

    before :all do
      @num_authors = 10
      (@num_authors - 1).times do |i|
        # mysql does typecasting of strings to ints, so start values at 0
        # so that the query using string tests don't find the 0 values.
        a = Author.create(num_val: i + 1,
                          str_val: "str #{i}",
                          published: (i == 0),
                          published_at: (i == 0) ? nil : Time.at(0).utc + i)
        2.times do |j|
          a.add_book(Book.create(num_val: j + 1, str_val: "str #{i} #{j}"))
        end
      end

      @owner_nil_num = Author.create(str_val: 'no num', published: false, published_at: Time.at(0).utc + @num_authors)
      @queryable_attributes = Set.new(%w(num_val str_val author_id book_id published published_at))
    end

    describe '#filtered_dataset_from_query_params' do
      describe 'no query' do
        it 'should return the full dataset' do
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                        @queryable_attributes, {})
          expect(ds.count).to eq(@num_authors)
        end
      end

      describe 'integer queries' do
        it 'filters equality queries when there are matches' do
          q = 'num_val:5'
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                        @queryable_attributes, q: q)
          expect(ds.all).to eq([Author[num_val: 5]])
        end

        it 'filters equality queries when there are no matches' do
          q = "num_val:#{@num_authors + 10}"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
            @queryable_attributes, q: q)
          expect(ds.count).to eq(0)
        end

        it 'filters equality queries when the argument is a string' do
          q = 'num_val:a'
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                        @queryable_attributes, q: q)
          expect(ds.count).to eq(0)
        end

        it 'filters greater-than comparisons' do
          q = "num_val>#{@num_authors - 5}"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
            @queryable_attributes, q: q)

          expected = Author.all.select do |a|
            a.num_val && a.num_val > @num_authors - 5
          end

          expect(ds.all).to match_array(expected)
        end

        it 'filters great-than-or-equal comparisons' do
          q = "num_val>=#{@num_authors - 5}"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
            @queryable_attributes, q: q)

          expected = Author.all.select do |a|
            a.num_val && a.num_val >= @num_authors - 5
          end

          expect(ds.all).to match_array(expected)
        end

        it 'filters less-than comparisons' do
          q = "num_val<#{@num_authors - 5}"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
            @queryable_attributes, q: q)

          expected = Author.all.select do |a|
            a.num_val && a.num_val < @num_authors - 5
          end

          expect(ds.all).to match_array(expected)
        end

        it 'filters less-than-or-equal comparisons' do
          q = "num_val<=#{@num_authors - 5}"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
            @queryable_attributes, q: q)

          expected = Author.all.select do |a|
            a.num_val && a.num_val <= @num_authors - 5
          end

          expect(ds.all).to match_array(expected)
        end
      end

      describe 'string queries' do
        it 'filters equality queries when there are matches' do
          q = 'str_val:str 5'
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                        @queryable_attributes, q: q)
          expect(ds.all).to eq([Author[str_val: 'str 5']])
        end

        it 'filters equality queries when there are no matches' do
          q = 'str_val:fnord'
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                        @queryable_attributes, q: q)
          expect(ds.count).to eq(0)
        end

        it 'does not match partial strings' do
          q = 'str_val:str'
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                        @queryable_attributes, q: q)
          expect(ds.count).to eq(0)
        end
      end

      describe 'timestamp queries' do
        describe 'exact query on a timestamp' do
          it 'returns the correct record when when the timestamp is null' do
            q = 'published_at:'
            ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
              @queryable_attributes, q: q)
            expect(ds.all).to eq([Author[num_val: 1]])
          end

          it 'returns the correct record when the timestamp is valid' do
            query_value = Author[num_val: 5].published_at
            q = "published_at:#{query_value}"
            ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
              @queryable_attributes, q: q)
            expect(ds.all).to eq([Author[num_val: 5]])
          end
        end

        it 'returns correct results for a greater-than comparison query' do
          query_value = Author[num_val: 5].published_at
          q = "published_at>#{query_value}"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
          @queryable_attributes, q: q)

          expected = Author.all.select do |a|
            a.published_at && a.published_at > query_value
          end

          expect(ds.all).to match_array(expected)
        end

        it 'returns correct results for a greater-than-or-equal-to comparison query' do
          query_value = Author[num_val: 5].published_at
          q = "published_at>=#{query_value}"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
            @queryable_attributes, q: q)

          expected = Author.all.select do |a|
            a.published_at && a.published_at >= query_value
          end

          expect(ds.all).to match_array(expected)
        end

        it 'returns correct results for a less-than comparison query' do
          query_value = Author[num_val: 5].published_at
          q = "published_at<#{query_value}"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
            @queryable_attributes, q: q)

          expected = Author.all.select do |a|
            a.published_at && a.published_at < query_value
          end

          expect(ds.all).to match_array(expected)
        end

        it 'returns correct results for a less-than-or-equal-to comparison query' do
          query_value = Author[num_val: 5].published_at
          q = "published_at<=#{query_value}"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
            @queryable_attributes, q: q)

          expected = Author.all.select do |a|
            a.published_at && a.published_at <= query_value
          end

          expect(ds.all).to match_array(expected)
        end

        it 'returns no results for an exact query on a invalid timestamp' do
          query_value = Author.last.published_at + 1
          q = "published_at:#{query_value}"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
            @queryable_attributes, q: q)

          expect(ds.count).to eq(0)
        end

        it 'raises argument error for an exact query on a malformed timestamp' do
          q = 'published_at:asdf'

          expect { Query.filtered_dataset_from_query_params(Author, Author.dataset,
            @queryable_attributes, q: q)
          }.to raise_error(ArgumentError)
        end
      end

      describe 'boolean values on boolean column' do
        it 'returns correctly filtered results for t' do
          ds = Query.filtered_dataset_from_query_params(
            Author, Author.dataset, @queryable_attributes, q: 'published:t')
          expect(ds.all).to eq([Author.first])
        end

        it 'returns correctly filtered results for true' do
          ds = Query.filtered_dataset_from_query_params(
            Author, Author.dataset, @queryable_attributes, q: 'published:true')
          expect(ds.all).to eq([Author.first])
        end

        it 'returns correctly filtered results for f' do
          ds = Query.filtered_dataset_from_query_params(
            Author, Author.dataset, @queryable_attributes, q: 'published:f')
          expect(ds.all).to eq(Author.all - [Author.first])
        end

        it 'returns correctly filtered results for false' do
          ds = Query.filtered_dataset_from_query_params(
            Author, Author.dataset, @queryable_attributes, q: 'published:false')
          expect(ds.all).to eq(Author.all - [Author.first])
        end

        it 'returns resulted filtered as false for any other value' do
          ds = Query.filtered_dataset_from_query_params(
            Author, Author.dataset, @queryable_attributes, q: 'published:foobar')
          expect(ds.all).to eq(Author.all - [Author.first])
        end
      end

      describe 'errors' do
        it 'raises for nonexistent attributes' do
          q = 'bogus_val:1'
          expect {
            Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                          @queryable_attributes, q: q)
          }.to raise_error(VCAP::Errors::ApiError, /query parameter is invalid/)
        end

        it 'raises on nonexistent foreign_keys' do
          q = 'fake_foreign_key_guid:1'
          expect {
            Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                          [*@queryable_attributes, 'fake_foreign_key_guid'], q: q)
          }.to raise_error(VCAP::Errors::ApiError, /query parameter is invalid/)
        end

        it 'raises on nonexistent attributes that do exist in queryable_attributes' do
          q = 'fake_attr:1'
          expect {
            Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                          [*@queryable_attributes, 'fake_attr'], q: q)
          }.to raise_error(VCAP::Errors::ApiError, /query parameter is invalid/)
        end

        it 'raises on nonallowed attributes' do
          q = 'protected:1'
          expect {
            Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                          @queryable_attributes, q: q)
          }.to raise_error(VCAP::Errors::ApiError, /query parameter is invalid/)
        end

        it 'raises when there is no key' do
          q = ':10'
          expect {
            Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                          @queryable_attributes, q: q)
          }.to raise_error(VCAP::Errors::ApiError, /query parameter is invalid/)
        end
      end

      describe 'querying multiple values' do
        it 'should return the correct record' do
          q = 'num_val:5;str_val:str 4'
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
            @queryable_attributes, q: q)
          expect(ds.all).to eq([Author[num_val: 5, str_val: 'str 4']])
        end

        it "should support multiple 'q' parameters" do
          q = ['num_val:5', 'str_val:str 4']
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
            @queryable_attributes, q: q)
          expect(ds.all).to eq([Author[num_val: 5, str_val: 'str 4']])
        end
      end

      describe 'exact query with nil value' do
        it 'should return records with nil entries' do
          q = 'num_val:'
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                        @queryable_attributes, q: q)
          expect(ds.all).to eq([@owner_nil_num])
        end
      end

      describe 'querying to_many relations' do
        it 'returns no results for a nonexistent id' do
          q = 'book_id:9999'
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                        @queryable_attributes, q: q)
          expect(ds.count).to eq(0)
        end

        it 'returns results that match the id' do
          q = 'book_id:2'
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                        @queryable_attributes, q: q)
          expect(ds.all).to eq([Author[Book[2].author_id]])
        end
      end

      describe 'querying to_one relations' do
        it 'returns no results for a nonexistent id' do
          q = 'author_id:9999'
          ds = Query.filtered_dataset_from_query_params(Book, Book.dataset,
                                                        @queryable_attributes, q: q)
          expect(ds.count).to eq(0)
        end

        it 'return results that match the id' do
          q = 'author_id:1'
          ds = Query.filtered_dataset_from_query_params(Book, Book.dataset,
                                                        @queryable_attributes, q: q)
          expect(ds.all).to eq(Author[1].books)
        end
      end

      context 'when the model has a guid' do
        let!(:magazine1) { Magazine.create(guid: SecureRandom.uuid) }
        let!(:magazine2) { Magazine.create(guid: SecureRandom.uuid) }
        let!(:magazine_with_no_subscribers) { Magazine.create(guid: SecureRandom.uuid) }
        let!(:subscriber1_magazine1) { Subscriber.create(guid: SecureRandom.uuid, magazine: magazine1) }
        let!(:subscriber2_magazine1) { Subscriber.create(guid: SecureRandom.uuid, magazine: magazine1) }
        let!(:subscriber1_magazine2) { Subscriber.create(guid: SecureRandom.uuid, magazine: magazine2) }

        describe 'exact query with an guid from a to_many relation' do
          it 'returns the correct results' do
            q = "subscriber_guid:#{subscriber1_magazine1.guid}"
            ds = Query.filtered_dataset_from_query_params(Magazine, Magazine.dataset,
                                                          Set.new(['subscriber_guid']), q: q)
            expect(ds.all).to eq([magazine1])
          end
        end

        describe 'IN query with a single guid from a to_many relation' do
          it 'returns the correct results' do
            q = "subscriber_guid IN #{subscriber1_magazine1.guid}"
            ds = Query.filtered_dataset_from_query_params(Magazine, Magazine.dataset,
                                                          Set.new(['subscriber_guid']), q: q)
            expect(ds.all).to eq([magazine1])
          end
        end

        describe 'IN query with a multiple guids from a to_many relation' do
          it 'returns the correct results' do
            q = "subscriber_guid IN #{subscriber1_magazine1.guid},#{subscriber1_magazine2.guid}"
            ds = Query.filtered_dataset_from_query_params(Magazine, Magazine.dataset,
                                                          Set.new(['subscriber_guid']), q: q)
            expect(ds.all).to match_array([magazine1, magazine2])
          end
        end

        describe 'exact query with an guid from a to_one relation' do
          it 'returns the correct results' do
            q = "magazine_guid:#{magazine1.guid}"
            ds = Query.filtered_dataset_from_query_params(Subscriber, Subscriber.dataset,
                                                          Set.new(['magazine_guid']), q: q)
            expect(ds.all).to match_array([subscriber1_magazine1, subscriber2_magazine1])
          end
        end

        describe 'IN query with a single guid from a to_one relation' do
          it 'returns the correct results' do
            q = "magazine_guid IN #{magazine1.guid}"
            ds = Query.filtered_dataset_from_query_params(Subscriber, Subscriber.dataset,
                                                          Set.new(['magazine_guid']), q: q)
            expect(ds.all).to match_array([subscriber1_magazine1, subscriber2_magazine1])
          end
        end

        describe 'IN query with a multiple guids from a to_one relation' do
          it 'returns the correct results' do
            q = "magazine_guid IN #{magazine1.guid},#{magazine2.guid}"
            ds = Query.filtered_dataset_from_query_params(Subscriber, Subscriber.dataset,
                                                          Set.new(['magazine_guid']), q: q)
            expect(ds.all).to match_array([subscriber1_magazine1, subscriber2_magazine1, subscriber1_magazine2])
          end
        end
      end

      describe 'query on an array of possible values' do
        it 'returns all of the matching records when using strings' do
          q = 'str_val IN str 1,str 2,str IN 3'
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                        @queryable_attributes, q: q)

          expected = Author.all.select do |a|
            a.str_val == 'str 1' || a.str_val == 'str 2'
          end

          expect(ds.all).to match_array(expected)
        end

        it 'returns all of the matching records when using timestamps' do
          author1 = Author[num_val: 2]
          author2 = Author[num_val: 3]
          q = "published_at IN #{author1.published_at.utc.iso8601},#{author2.published_at.utc.iso8601}"
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                        @queryable_attributes, q: q)

          expect(ds.all).to match_array([author1, author2])
        end

        it 'returns all of the matching records when using integers' do
          author1 = Author[num_val: 2]
          author2 = Author[num_val: 3]
          q = 'num_val IN 2,3'
          ds = Query.filtered_dataset_from_query_params(Author, Author.dataset,
                                                        @queryable_attributes, q: q)

          expect(ds.all).to match_array([author1, author2])
        end
      end
    end

    describe 'semicolon escaping' do
      let!(:one_semi) { VCAP::CloudController::TestModel.make(unique_value: 'one_semi;', required_attr: true) }
      let!(:multiple_semi) { VCAP::CloudController::TestModel.make(unique_value: 'two;;semis and one;semi') }
      let(:queryable_attributes) { Set.new(%w(unique_value required_attr)) }

      describe '#filtered_dataset_from_query_params' do
        it 'matches with a semicolon at the end' do
          q = 'unique_value:one_semi;;'
          ds = Query.filtered_dataset_from_query_params(VCAP::CloudController::TestModel, VCAP::CloudController::TestModel.dataset, queryable_attributes, q: q)
          expect(ds.all).to eq [one_semi]
        end

        it 'matches on multiple semicolons' do
          q = 'unique_value:two;;;;semis and one;;semi'
          ds = Query.filtered_dataset_from_query_params(VCAP::CloudController::TestModel, VCAP::CloudController::TestModel.dataset, queryable_attributes, q: q)
          expect(ds.all).to eq [multiple_semi]
        end

        it 'matches with multiple query params' do
          q = 'unique_value:one_semi;;;required_attr:t'
          ds = Query.filtered_dataset_from_query_params(VCAP::CloudController::TestModel, VCAP::CloudController::TestModel.dataset, queryable_attributes, q: q)
          expect(ds.all).to eq [one_semi]

          q = 'unique_value:one_semi;;;required_attr:f'
          ds = Query.filtered_dataset_from_query_params(VCAP::CloudController::TestModel, VCAP::CloudController::TestModel.dataset, queryable_attributes, q: q)
          expect(ds.all).to eq []
        end
      end
    end
  end
end
