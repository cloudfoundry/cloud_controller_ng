# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::ModelSpecHelper
  shared_examples "timestamps" do |opts|
    let(:obj) { described_class.make }

    before(:all) do
      @orig_created_at = obj.created_at
      obj.updated_at.should be_nil
      obj.save
    end

    it "should not update the created_at timestamp" do
      obj.created_at.should == @orig_created_at
    end

    it "should have a recent updated_at timestamp" do
      obj.updated_at.should be_recent
    end
  end
end
