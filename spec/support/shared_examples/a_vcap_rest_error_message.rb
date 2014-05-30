shared_examples "a vcap rest error response" do |description_match|
  let(:decoded_response) { Yajl::Parser.parse(last_response.body) }

  it "should contain a numeric code" do
    decoded_response["code"].should_not be_nil
    decoded_response["code"].should be_a_kind_of(Fixnum)
  end

  it "should contain a description" do
    decoded_response["description"].should_not be_nil
    decoded_response["description"].should be_a_kind_of(String)
  end

  if description_match
    it "should contain a description that matches #{description_match}" do
      decoded_response["description"].should match(/#{description_match}/)
    end
  end
end
