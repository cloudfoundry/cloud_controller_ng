module ModelHelpers
  shared_examples "creation with all required attributes" do
    describe "with all required attributes" do
      before(:all) do
        @obj = described_class.make
      end

      it "should succeed" do
        @obj.should be_valid
      end

      it "should have a recent created_at timestamp" do
        @obj.created_at.should be_recent
      end

      it "should not have an updated_at timestamp" do
        @obj.updated_at.should be_nil
      end
    end
  end
end
