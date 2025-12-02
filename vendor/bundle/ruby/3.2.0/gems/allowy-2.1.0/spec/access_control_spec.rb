require 'spec_helper'

module Allowy
  describe "checking permissions" do

    let(:access)  { SampleAccess.new(123) }
    subject       { access }

    describe "#context as an arbitrary object" do
      subject     { access.context }
      its(:to_s)  { should == '123' }
      its(:zero?) { should == false }

      it "should be able to access the context" do
        access.should be_able_to :context_is_123
      end
    end

    it { should be_able_to :read, 'allow' }
    it { should_not be_able_to :read, 'deny' }

    it "should pass extra parameters" do
      access.should be_able_to :extra_params, 'same', bar: 'same'
    end

    it "should deny with early termination" do
      access.should_not be_able_to :early_deny, 'foo'
      access.can?(:early_deny, 'xx').should == false
    end

    it "should raise if no permission defined" do
      lambda { subject.can? :write, 'allow' }.should raise_error(UndefinedAction) {|err|
        err.message.should include 'write?'
      }
    end


    describe "#authorize!" do
      it "shuold raise error" do
        expect { subject.authorize! :read, 'deny' }.to raise_error AccessDenied do |err|
          err.message.should_not be_blank
          err.action.should == :read
          err.subject.should == 'deny'
        end
      end

      it "should not raise error" do
        expect { subject.authorize! :read, 'allow' }.not_to raise_error
      end

      it "should raise early termination error with payload" do
        expect { subject.authorize! :early_deny, 'subject' }.to raise_error AccessDenied do |err|
          err.message.should_not be_blank
          err.action.should == :early_deny
          err.subject.should == 'subject'
          err.payload.should == 'early terminate: subject'
        end
      end

    end

  end

end
