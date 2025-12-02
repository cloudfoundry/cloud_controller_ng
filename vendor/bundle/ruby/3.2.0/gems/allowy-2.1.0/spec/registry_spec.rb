require 'spec_helper'

module Allowy
  describe Registry do
    let(:context) { 123 }
    subject       { Registry.new context }

    describe "#access_control_for!" do

      it "should find AC by appending Access to the subject" do
        subject.access_control_for!(Sample.new).should be_a SampleAccess
      end

      it "should find AC by appending custom suffix to the subject" do
        registry = Registry.new(context, access_suffix: 'Permission')
        registry.access_control_for!(Sample.new).should be_a SamplePermission
      end

      it "raises on invalid option" do
        expect { Registry.new(context, foo: 'incorrect option') }.to raise_error /unknown key/i
      end

      it "should find AC when the subject is a class" do
        subject.access_control_for!(Sample).should be_a SampleAccess
      end

      it "should raise when AC is not found by the subject" do
        lambda { subject.access_control_for!(123) }.should raise_error(UndefinedAccessControl) {|err|
          err.message.should include '123'
        }
      end

      it "should raise when subject is nil" do
        lambda { subject.access_control_for!(nil) }.should raise_error UndefinedAccessControl
      end

      it "should return NilClassAccess when subject is nil and NilClassAccess is defined" do
        nil_class_access = Class.new do
          include Allowy::AccessControl
        end
        stub_const("NilClassAccess", nil_class_access)
        subject.access_control_for!(nil).should be_a nil_class_access
      end

      it "should return the same AC instance" do
        first = subject.access_control_for!(Sample)
        secnd = subject.access_control_for!(Sample)
        first.should === secnd
      end

      it "should support objects that provide source_class method (such as Draper)" do
        decorator_class = Class.new do
          def self.source_class
            Sample
          end
        end
        decorated_object = decorator_class.new
        subject.access_control_for!(decorated_object).should be_a SampleAccess
      end

    end
  end
end
