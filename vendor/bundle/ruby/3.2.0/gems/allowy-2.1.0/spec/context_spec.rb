require 'spec_helper'

module Allowy
  class SampleContext
    include Context
  end

  describe Context do

    subject { SampleContext.new }
    let(:access) { double("Access") }

    it "should create a registry" do
      expect(Registry).to receive(:new).with(subject)
      subject.current_allowy
    end

    it "should be able to check using can?" do
      expect(subject.current_allowy).to receive(:access_control_for!).with(123).and_return access
      expect(access).to receive(:can?).with(:edit, 123)
      subject.can?(:edit, 123)
    end

    it "should be able to check using cannot?" do
      expect(subject.current_allowy).to receive(:access_control_for!).with(123).and_return access
      expect(access).to receive(:cannot?).with(:edit, 123)
      subject.cannot?(:edit, 123)
    end

    it "should call authorize!" do
      expect(access).to receive(:authorize!).with :edit, 123
      allow(subject.current_allowy).to receive(:access_control_for!).and_return access
      subject.authorize! :edit, 123
    end
  end
end

