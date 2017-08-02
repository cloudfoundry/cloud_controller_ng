require 'spec_helper'

module VCAP::RestAPI
  RSpec.describe VCAP::RestAPI::EventQuery do
    include VCAP::RestAPI

    class EventAuthor < Sequel::Model
      one_to_many :event_books
    end

    class EventBook < Sequel::Model
      many_to_one :event_author
    end

    class EventMagazine < Sequel::Model
      one_to_many :event_subscribers
    end

    class EventSubscriber < Sequel::Model
      many_to_one :event_magazine
    end

    before :all do
      @num_authors = 10
      (@num_authors - 1).times do |i|
        # mysql does typecasting of strings to ints, so start values at 0
        # so that the query using string tests don't find the 0 values.
        a = EventAuthor.create(num_val: i + 1,
                               str_val:      "str #{i}",
                               published:    (i == 0),
                               published_at: (i == 0) ? nil : Time.at(0).utc + i)
        2.times do |j|
          a.add_event_book(EventBook.create(num_val: j + 1, str_val: "str #{i} #{j}"))
        end
      end
    end

    describe '#filtered_dataset_from_query_params' do
      context 'when the model has a guid but foreign key associations are ignored' do
        let!(:magazine1) { EventMagazine.create(guid: SecureRandom.uuid) }
        let!(:magazine2) { EventMagazine.create(guid: SecureRandom.uuid) }
        let!(:subscriber1_magazine1) { EventSubscriber.create(guid: SecureRandom.uuid, event_magazine: magazine1) }
        let!(:subscriber1_magazine2) { EventSubscriber.create(guid: SecureRandom.uuid, event_magazine: magazine2) }

        describe 'exact query with a guid from a to_many relation' do
          it 'fails to resolve the foreign key' do
            q = "subscriber_guid:#{subscriber1_magazine1.guid}"
            expect {
              EventQuery.filtered_dataset_from_query_params(EventMagazine, EventMagazine.dataset,
                                                            Set.new(['subscriber_guid']), q: q)
            }.to raise_error(CloudController::Errors::ApiError, /query parameter is invalid/)
          end
        end

        describe 'IN query with multiple guids from a to_many relation' do
          it 'fails to resolve the foreign key' do
            q = "subscriber_guid IN #{subscriber1_magazine1.guid},#{subscriber1_magazine2.guid}"
            expect {
              EventQuery.filtered_dataset_from_query_params(EventMagazine, EventMagazine.dataset,
                                                            Set.new(['subscriber_guid']), q: q)
            }.to raise_error(CloudController::Errors::ApiError, /query parameter is invalid/)
          end
        end
      end
    end
  end
end
