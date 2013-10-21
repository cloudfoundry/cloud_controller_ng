module ModelHelpers
  shared_examples "timestamps" do |opts|
    before(:all) do
      @obj = described_class.make
      @created_at = @obj.created_at
      @obj.updated_at.should be_nil
      @obj.save
    end

    it "should not update the created_at timestamp" do
      @obj.created_at.should == @created_at
    end

    it "should have a recent updated_at timestamp" do
      @obj.updated_at.should be_recent
    end
  end
end
