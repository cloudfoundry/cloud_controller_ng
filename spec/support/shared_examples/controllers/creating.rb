shared_examples "creating" do |opts|
  opts[:extra_attributes] ||= {}

  describe "creating" do
    let(:creation_opts) do
      opts[:create_attribute_reset].call if opts[:create_attribute_reset]

      initial_obj = opts[:model].make
      attrs = CreationOptionsFromObject.options(initial_obj, opts)
      initial_obj.destroy

      opts[:extra_attributes].each do |attr, val|
        attrs[attr.to_s] = val.respond_to?(:call) ? val.call : val
      end

      attrs
    end

    let(:non_extra_creation_opts) do
      res = {}
      creation_opts.each do |k, v|
        res[k] = v unless opts[:extra_attributes].keys.include?(k.to_sym)
      end
      res
    end

    path_desc = opts[:path]
    describe "POST #{path_desc}" do
      context "with all required attributes" do
        before do
          json_body = Yajl::Encoder.encode(creation_opts)

          post opts[:path], json_body, json_headers(admin_headers)
        end

        it "should return 201" do
          last_response.status.should == 201
        end

        include_examples "return a vcap rest encoded object"

        it "should return the json encoded object in the entity hash" do
          non_extra_creation_opts.keys.each do |k|
            unless k == "guid"
              entity[k.to_s].should_not be_nil
              entity[k.to_s].should == creation_opts[k]
            end
          end
        end

        it "should return the path to the new instance in the location header" do
          last_response.location.should_not be_nil
          last_response.location.should match %(#{opts[:path]}/[^ /])
          metadata["url"].should == last_response.location
        end

        it "should return the request guid in the header" do
          last_response.headers["X-VCAP-Request-ID"].should_not be_nil
        end

        it "should have created the object pointed to in the location header" do
          obj_id = last_response.location.split("/").last
          obj = opts[:model].find(guid: obj_id)
          non_extra_creation_opts.keys.each do |k|
            obj.send(k).should == creation_opts[k]
          end
        end
      end
    end
  end
end
