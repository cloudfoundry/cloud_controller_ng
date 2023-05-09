require 'spec_helper'
require File.expand_path('../../../db/helpers/remove_duplicates', __dir__)

RSpec.describe 'remove_duplicates' do
  let(:db) { DbConfig.new.connection }

  before do
    db.create_table :dummy do
      primary_key :id
      String :column_1
      String :column_2
      String :column_3
    end
  end

  after do
    db.drop_table(:dummy)
  end

  it 'should remove duplicate entries based on column values' do
    db[:dummy].insert(column_1: 'value1', column_2: 'value2', column_3: 'value3')
    db[:dummy].insert(column_1: 'value1', column_2: 'value2', column_3: 'value3')
    db[:dummy].insert(column_1: 'value1', column_2: 'value2', column_3: 'value3')
    db[:dummy].insert(column_1: 'value1', column_2: 'value2', column_3: 'value3_different')
    db[:dummy].insert(column_1: 'value1', column_2: 'value2_different', column_3: 'value3')
    db[:dummy].insert(column_1: 'value1', column_2: 'value2_different', column_3: 'value3')

    expect(db[:dummy].count).to eq(6)

    remove_duplicates(db, :dummy, :column_1, :column_2, :column_3)

    expect(db[:dummy].count).to eq(3)
  end
end
