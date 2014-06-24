shared_examples "model instance" do |opts|
  ([:sensitive_attributes, :extra_json_attributes, :disable_examples]).each do |k|
    opts[k] ||= []
    opts[k] = Array[opts[k]] unless opts[k].respond_to?(:each)
  end

  unless opts[:disable_examples].include? :creation
    describe "creation" do
      include_examples "creation with all required attributes"
    end
  end

  unless opts[:disable_examples].include? :deletion
    describe "deletion" do
      let(:obj) { described_class.make }

      it "should succeed" do
        obj.destroy(savepoint: true)
      end
    end
  end
end

