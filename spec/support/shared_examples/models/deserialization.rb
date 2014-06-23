shared_examples "deserialization" do |opts|
  let(:json_data) do
    obj = described_class.make
    hash = obj.as_json
    obj.destroy(savepoint: true)

    # used for things like password that we don't export
    opts[:extra_json_attributes].each do |attr|
      hash[attr] = Sham.send(attr)
    end

    Yajl::Encoder.encode(hash)
  end

  it "should succeed" do
    obj = described_class.new_from_hash(Yajl::Parser.parse(json_data))
    obj.should be_valid
  end
end

