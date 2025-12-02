require 'spec_helper'

describe Vmstat::Task do
  context "Vmstat#task" do
    let(:task) { Vmstat.task }
    subject { task }

    it "should be a vmstat task object" do
      should be_a(described_class)
    end

    context "methods" do
      it { should respond_to(:virtual_size) }
      it { should respond_to(:resident_size) }
      it { should respond_to(:user_time_ms) }
      it { should respond_to(:system_time_ms) }
    end
    
    context "content" do
      its(:virtual_size) { should be_a_kind_of(Numeric) }
      its(:resident_size) { should be_a_kind_of(Numeric) }
      its(:user_time_ms) { should be_a_kind_of(Numeric) }
      its(:system_time_ms) { should be_a_kind_of(Numeric) }
    end
  end
end if RUBY_PLATFORM =~ /darwin|linux/

