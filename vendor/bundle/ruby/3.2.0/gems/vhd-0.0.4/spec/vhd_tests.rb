require 'spec_helper'

describe "vhds" do
  before(:each) do
    @file = Tempfile.new(Faker::Name.first_name.downcase)
  end

  let(:file_name) { @file.path }

  it "should create a fixed vhd" do
    disk = Vhd::Library.new(type: :fixed, size: 1, name: file_name)
    disk.create
  end

  after(:each) do
    @file.close
  end
end
