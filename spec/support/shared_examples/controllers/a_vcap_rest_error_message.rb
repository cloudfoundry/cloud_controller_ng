shared_examples "a vcap rest error response" do |description_match|
  let(:decoded_response) { Yajl::Parser.parse(last_response.body) }

  it "is a proper error response" do
    decoded_response["code"].should be_a_kind_of(Fixnum)
    decoded_response["description"].should be_a_kind_of(String)
    decoded_response["description"].should match(/#{description_match}/) if description_match
  end
end