# Copyright (c) 2009-2012 VMware, Inc.

module VCAP::CloudController::ModelSpecHelper
  shared_examples "deserialization" do |opts|
    context "with all required attributes" do
      let(:json_data) do
        hash = {}

        obj = described_class.make
        opts[:required_attributes].each do |attr|
          if described_class.associations.include?(attr)
            hash["#{attr}_guid"] = obj.send(attr).guid
          else
            hash[attr] = obj.send(attr)
          end
        end

        obj.destroy

        # used for things like password that we don't export
        opts[:extra_json_attributes].each do |attr|
          hash[attr] = Sham.send(attr)
        end

        Yajl::Encoder.encode(hash)
      end

      it "should succeed" do
        obj = described_class.create_from_json(json_data)
        obj.should be_valid
      end
    end

    opts[:required_attributes].each do |without_attr|
      context "without the :#{without_attr.to_s} attribute" do
        let(:json_data) do
          obj = described_class.create do |instance|
            instance.set_all(creation_opts)
          end
          hash = obj.to_hash
          obj.destroy

          # used for things like password that we don't export
          opts[:extra_json_attributes].each do |attr|
            attr = attr.to_s
            # This is a bit of a hack.  It would be better to somehow indicate
            # the relationship between derived attributes from the json
            # attributes
            unless without_attr == "crypted_#{attr}".to_sym
              hash[attr] = Sham.send(attr)
            end
          end

          hash.select! do |k, v|
            k != without_attr.to_s and k != "#{without_attr}_guid"
          end

          Yajl::Encoder.encode(hash)
        end

        it "should fail due to Sequel validations" do
          # keep this out of the lambda to make sure we are testing the
          # right exception
          data = json_data
          expect {
            obj = described_class.create_from_json(data)
          }.to raise_error Sequel::ValidationFailed, /#{without_attr}/
        end
      end
    end
  end
end
