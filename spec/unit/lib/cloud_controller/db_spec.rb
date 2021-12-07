require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Sequel::Database do
    describe 'when running with a PostgreSQL database', skip: User.db.database_type != :postgres do
      let(:conversion_proc) { User.db.conversion_procs[1114] }

      it "does not use the default method for 'timestamp without time zone' conversion" do
        expect(conversion_proc).not_to be_a(Method)
      end

      describe 'when reading data from the database' do
        it 'correctly converts timestamp fields using the custom conversion proc' do
          t = Time.now
          User.make

          u = User.first
          expect(u.created_at).to be_within(10.seconds).of t
          expect(u.updated_at).to be_within(10.seconds).of t
        end
      end

      describe 'when using the custom conversion proc' do
        it 'converts timestamp strings in the ISO 8601 extended format without fractional seconds' do
          t = conversion_proc.call('2013-12-11 10:09:08')
          expect(t.to_i).to eq(Time.utc(2013, 12, 11, 10, 9, 8).to_i)
        end

        it 'converts timestamp strings in the ISO 8601 extended format with fractional seconds' do
          t = conversion_proc.call('2013-12-11 10:09:08.765')
          expect(t.to_i).to eq(Time.utc(2013, 12, 11, 10, 9, 8.765).to_i)
        end

        it 'does not support other timestamp formats (e.g. ISO 8601 basic format)' do
          expect { conversion_proc.call('20131211T100908Z') }.to raise_error(StandardError)
        end
      end
    end
  end
end
