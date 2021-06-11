require 'spec_helper'

module VCAP::CloudController
  RSpec.describe Sequel::Dataset do
    describe '#post_load', type: :model do
      let(:logs) { StringIO.new }
      let(:logger) { Logger.new(logs) }

      before do
        Route.db.loggers << logger
      end

      it 'log the number of returned rows' do

        space=Space.make
        Route.make(space: space)
        Route.dataset.eager(:space).all
        expect(logs.string).to match "Loaded 1 records from table \"routes\" with 1 associations"
      end
    end
  end
end
