require 'spec_helper'

describe Sequel::Model do
  it 'should load classes with non-default primary key' do
    expect do
      YAML.load(Story.create.to_yaml)
    end.not_to raise_error
  end
end
