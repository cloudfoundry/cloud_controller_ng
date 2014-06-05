module ControllerExamples
  shared_examples "return a vcap rest encoded object" do
    it "returns a vcap rest encoded object" do
      metadata.should be_a_kind_of(Hash)
      metadata["guid"].should_not be_nil
      metadata["url"].should be_a_kind_of(String)

      entity.should be_a_kind_of(Hash)
    end
  end
end
