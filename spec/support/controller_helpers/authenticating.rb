module ControllerHelpers
  shared_examples "uaa authenticated api" do |opts|
    context "with invalid auth header" do
      subject do
        headers = headers_for(User.make)
        headers["HTTP_AUTHORIZATION"] += "EXTRA STUFF"
        get opts[:path], {}, headers
      end

      it "returns a 401" do
        subject
        expect(last_response.status).to eq 401
      end

      it "returns a vcap error code of 1000" do
        subject
        expect(decoded_response["code"]).to eq 1000
      end

      describe "must be in a block as the shared examples expect the subject to happen in a before block (which is non-idiomatic rspec)" do
        before { subject }
        it_behaves_like "a vcap rest error response", /Invalid Auth Token/
      end
    end

    context "with valid auth header" do
      unless opts[:path] == "/v2/users"
        context "for an existing user" do
          it "returns 200" do
            get opts[:path], {}, headers_for(User.make)
            last_response.status.should == 200
          end
        end

        context "for a new user" do
          it "returns 200" do
            get opts[:path], {}, headers_for(Machinist.with_save_nerfed { User.make })
            last_response.status.should == 200
          end
        end

        context "for a deleted user" do
          it "returns 200 by recreating the user" do
            user = User.make
            headers = headers_for(user)
            user.delete
            get opts[:path], {}, headers
            last_response.status.should == 200
          end
        end
      end

      context "for an admin" do
        it "should return 200" do
          get opts[:path], {}, headers_for(nil, :admin_scope => true)
          puts "Bad response! #{last_response.inspect}" unless last_response.status == 200
          last_response.status.should == 200
        end
      end

      context "for no user" do
        it "should return 401" do
          get opts[:path], {}, headers_for(nil)
          last_response.status.should == 401
        end
      end
    end
  end
end
