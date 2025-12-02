# frozen_string_literal: true

RSpec.describe RuboCop::Cop::Sequel::SaveChanges do
  subject(:cop) { described_class.new }

  it 'registers an offense when using save' do
    offenses = inspect_source('favorite.save')
    expect(offenses.size).to eq(1)
  end

  it 'does not register an offense when using save_changes' do
    offenses = inspect_source('favorite.save_changes')
    expect(offenses).to be_empty
  end

  it 'auto-corrects by using save_changes' do
    new_source = autocorrect_source('favorite.save')
    expect(new_source).to eq('favorite.save_changes')
  end
end
