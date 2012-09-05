# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::Drainer do
  before :each do
    @klass = Class.new(Drainer)
  end

  describe "increment_requests" do
    it "should increment requests" do
      @klass.setup
      10.times { @klass.increment_requests }
      @klass.requests.should == 10
    end
  end

  describe "decrement_requests" do
    it "should decrement requests" do
      @klass.setup
      10.times { @klass.decrement_requests }
      @klass.requests.should == -10
    end
  end

  describe "drain" do
    it "should call drain callbacks in correct order" do
      @klass.setup

      before_drain = lambda {}
      called = false
      before_drain.should_receive(:call) do
        called = true
      end
      @klass.queue_before_drain(&before_drain)

      after_drain = lambda {}
      after_drain.should_receive(:call) do
        raise unless called
      end
      @klass.queue_before_drain(&after_drain)

      @klass.drain
    end
  end

  context "raise errors" do
    it "should raise error when it is used before setup" do
      expect {
        @klass.increment_requests
      }.to raise_error(DrainerError, "Drainer has not been setup yet.")

      expect {
        @klass.decrement_requests
      }.to raise_error(DrainerError, "Drainer has not been setup yet.")

      expect {
        @klass.drain
      }.to raise_error(DrainerError, "Drainer has not been setup yet.")
    end

    it "should raise error when it is used in the wrong state" do
      @klass.setup
      @klass.drain

      expect {
        @klass.increment_requests
      }.to raise_error(DrainerError, "Invalid state!")

      expect {
        @klass.decrement_requests
      }.to raise_error(DrainerError, "Invalid state!")

      expect {
        @klass.drain
      }.to raise_error(DrainerError, "Invalid state!")

      expect {
        @klass.setup
      }.to raise_error(DrainerError, "Drainer has already been setup.")
    end
  end
end
