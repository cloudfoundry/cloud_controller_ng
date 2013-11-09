module ControllerHelpers
  shared_examples "deleting a valid object" do |opts|
    describe "deleting a valid object" do
      describe "DELETE #{opts[:path]}/:id" do
        let(:obj) { opts[:model].make }

        subject { delete "#{opts[:path]}/#{obj.guid}", {}, admin_headers }

        context "when there are no child associations" do
          before do
            if obj.is_a? Service
              # Blueprint makes a ServiceAuthToken. No other model has child associated models created by Blueprint.
              obj.service_auth_token.delete
            end
          end

          it "should return 204" do
            subject
            last_response.status.should == 204
          end

          it "should return an empty response body" do
            subject
            last_response.body.should be_empty
          end
        end

        context "when the object has a child associations" do
          around do |example|
            @associations = {}
            if opts[:one_to_many_collection_ids]
              @associations = opts[:one_to_many_collection_ids].map { |key, child| [key, child.call(obj)] }
              if opts[:excluded]
                @associations.select! { |name, _| !opts[:excluded].include?(name) }
              end
            end
            unless one_to_one_or_many.empty?
              example.run
            end
          end

          let(:one_to_one_or_many) do
            obj.class.associations.select do |association|
              next if opts[:excluded] && opts[:excluded].include?(association)

              if obj.class.association_dependencies_hash[association]
                if obj.class.association_dependencies_hash[association] == :destroy
                  obj.has_one_to_many?(association) || obj.has_one_to_one?(association)
                end
              end
            end
          end

          it "should return 400" do
            subject
            last_response.status.should == 400
          end

          it "should return the expected response body" do
            subject
            parsed_json = Yajl::Parser.parse(last_response.body)
            expect(parsed_json["code"]).to eq(10006)
            expect(parsed_json["description"]).to eq("Please delete the #{one_to_one_or_many.join(", ")} associations for your #{obj.class.table_name}.")
          end

          context "and the recursive param is passed in" do
            subject { delete "#{opts[:path]}/#{obj.guid}?recursive=#{recursive}", {}, admin_headers }

            context "and its true" do
              let(:recursive) { "true" }

              it "should return 204" do
                subject
                last_response.status.should == 204
              end

              it "should return an empty response body" do
                subject
                last_response.body.should be_empty
              end

              it "should delete all the child associations" do
                subject
                @associations.each do |name, association|
                  association.class[:id => association.id].should be_nil unless obj.class.association_reflection(name)[:type] == :many_to_many
                end
              end
            end

            context "and its false" do
              let(:recursive) { "false" }

              it "should return 400" do
                subject
                last_response.status.should == 400
              end

              it "should return the expected response body" do
                subject
                parsed_json = Yajl::Parser.parse(last_response.body)
                expect(parsed_json["code"]).to eq(10006)
                expect(parsed_json["description"]).to eq("Please delete the #{one_to_one_or_many.join(", ")} associations for your #{obj.class.table_name}.")
              end
            end
          end
        end
      end
    end
  end
end
