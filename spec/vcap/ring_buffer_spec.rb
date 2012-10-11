# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)
require "vcap/ring_buffer"

module VCAP
  describe RingBuffer do
    MAX_ENTRIES = 5
    let(:rb) { RingBuffer.new(MAX_ENTRIES) }

    context "empty" do
      it ".empty? should be true" do
        rb.empty?.should be_true
      end
    end

    context "with max push MAX_ENTRIES times" do
      before do
        MAX_ENTRIES.times do |i|
          rb.push i
        end
      end

      it ".empty? should be false" do
        rb.empty?.should be_false
      end

      it ".size should return MAX_ENTRIES" do
        rb.size.should == MAX_ENTRIES
      end

      it "should be in the correct order" do
        a = []
        MAX_ENTRIES.times { |i| a.push i }
        rb.should == a
      end

      it ".push should add a new entry and drop the old one" do
        rb.push "a"
        rb.should == [1, 2, 3, 4, "a"]
      end

      it ".<< should add a new entry and drop the old one" do
        rb << "a"
        rb.should == [1, 2, 3, 4, "a"]
      end
    end
  end
end
