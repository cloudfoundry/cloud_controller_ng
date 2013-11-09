module ControllerHelpers
  shared_examples "querying objects" do |opts|
    describe "querying objects" do
      before do
        5.times { opts[:model].make }
        Sham.reset(:before_each)
      end

      opts[:queryable_attributes].each do |attr|
        describe "#{opts[:path]}?q=#{attr}:<val>" do
          before do
            @val = Sham.send(attr)
            opts[:model].make(attr => @val)
          end

          describe "with a matching value" do
            before do
              get "#{opts[:path]}?q=#{attr}:#{@val}", {}, json_headers(admin_headers)
            end

            it "should return 200" do
              last_response.status.should == 200
            end

            it "should return total_results => 1" do
              decoded_response["total_results"].should == 1
            end
          end

          describe "with a non-existent value" do
            before do
              @non_existent_value = Sham.guid
              get "#{opts[:path]}?q=#{attr}:#{@non_existent_value}", {}, json_headers(admin_headers)
            end

            it "should return 200" do
              last_response.status.should == 200
            end

            it "should return total_results => 0" do
              decoded_response["total_results"].should == 0
            end
          end
        end
      end
    end
  end
end
