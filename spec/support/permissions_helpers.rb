shared_examples "a cf permission" do |name, nil_granted|
  nil_granted ||= false
  let(:no_role) { VCAP::CloudController::Roles.new }
  let(:admin_role) { VCAP::CloudController::Roles.new.tap{|r| r.admin = true} }

  describe "#granted_to?" do
    it "should return true for a #{name} user" do
      described_class.granted_to?(obj, granted, no_role).should be_true
    end

    it "should return false for non #{name} users" do
      described_class.granted_to?(obj, not_granted, no_role).should be_false
    end

    it "should return #{nil_granted} for a nil user" do
      described_class.granted_to?(obj, nil, no_role).should == nil_granted
    end
  end
end
