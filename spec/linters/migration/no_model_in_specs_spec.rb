require 'spec_helper'
require 'rubocop'
require 'rubocop/rspec/cop_helper'
require 'rubocop/config'
require 'linters/migration/no_model_in_specs'

RSpec.describe RuboCop::Cop::Migration::NoModelInSpecs do
  include CopHelper

  subject(:cop) { described_class.new(RuboCop::Config.new({})) }

  let(:message) do
    'Do not use model classes in migration specs. ' \
      'Use raw Sequel operations (e.g. db[:table].insert) instead. ' \
      'See spec/migrations/Readme.md for details.'
  end

  it 'registers an offense for Model.make' do
    result = inspect_source(<<~RUBY)
      VCAP::CloudController::AppModel.make
    RUBY

    expect(result.size).to eq(1)
    expect(result.map(&:message)).to eq([message])
  end

  it 'registers an offense for Model.make!' do
    result = inspect_source(<<~RUBY)
      VCAP::CloudController::AppModel.make!
    RUBY

    expect(result.size).to eq(1)
  end

  it 'registers an offense for Model.create' do
    result = inspect_source(<<~RUBY)
      VCAP::CloudController::DeploymentModel.create(guid: 'test')
    RUBY

    expect(result.size).to eq(1)
  end

  it 'registers an offense for Model.where' do
    result = inspect_source(<<~RUBY)
      VCAP::CloudController::AppModel.where(guid: 'test').first
    RUBY

    expect(result.size).to eq(1)
  end

  it 'does not register an offense for raw Sequel inserts' do
    result = inspect_source(<<~RUBY)
      db[:apps].insert(guid: 'test', name: 'test-app')
    RUBY

    expect(result.size).to eq(0)
  end

  it 'does not register an offense for Sequel::Model' do
    result = inspect_source(<<~RUBY)
      Sequel::Model.db
    RUBY

    expect(result.size).to eq(0)
  end

  it 'does not register an offense for non-Model constants' do
    result = inspect_source(<<~RUBY)
      SecureRandom.uuid
    RUBY

    expect(result.size).to eq(0)
  end
end
