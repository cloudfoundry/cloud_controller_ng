module ControllerHelpers
  shared_examples "reading a valid object" do |opts|
    describe "reading a valid object" do
      describe "GET #{opts[:path]}/:id" do
        before do
          @obj = opts[:model].make
          get "#{opts[:path]}/#{@obj.guid}", {}, json_headers(admin_headers)
        end

        it "should return 200" do
          last_response.status.should == 200
        end

        include_examples "return a vcap rest encoded object"

        it "should return the json encoded object in the response body" do
          expected = @obj.to_hash
          expected.each { |k, v| expected[k] = v.to_s if v.kind_of?(Time) }

          # filter out the relation urls.
          parsed = entity.select do |k, _|
            expected.has_key?(k) || (not k =~ /_url/)
          end
          parsed.should == expected

          opts[:basic_attributes].each do |attr|
            parsed.should have_key(attr.to_s)
          end
        end
      end
    end
  end
end
