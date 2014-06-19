module VCAP::CloudController
  shared_examples_for "name with semicolon is not valid" do |clazz|
    [";semicolon", "semi;colon", "semicolon;"].each do |name|
      it "should detect name format error for #{clazz.to_s} name with semicolon '#{name}'" do
        sbj = clazz.new(:name => name)
        sbj.validate
        expect(sbj.errors[:name]).to include(:format)
      end
    end
  end
end
