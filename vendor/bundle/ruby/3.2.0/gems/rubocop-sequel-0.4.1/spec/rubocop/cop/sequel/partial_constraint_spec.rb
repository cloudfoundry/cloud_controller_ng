# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Sequel::PartialConstraint do
  include Spec::Helpers::Migration

  subject(:cop) { described_class.new }

  it 'registers an offense when using where for constraint' do
    offenses = inspect_source_within_migration(<<~RUBY)
      add_unique_constraint %i[col_1 col_2], where: "state != 'deleted'"
    RUBY

    expect(offenses.size).to eq(1)
  end
end
