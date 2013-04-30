require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
  describe VCAP::CloudController::Models::ServiceBinding do
    it_behaves_like "a CloudController model", {
      :required_attributes => [:service_instance, :app],
      :unique_attributes   => [:app, :service_instance],
      :create_attribute    => lambda { |name|
        @space ||= Models::Space.make
        case name.to_sym
        when :app
          Models::App.make(:space => @space)
        when :service_instance
          Models::ServiceInstance.make(:space => @space)
        end
      },
      :create_attribute_reset => lambda { @space = nil },
      :many_to_one => {
        :app => {
          :delete_ok => true,
          :create_for => lambda { |service_binding|
            Models::App.make(:space => service_binding.space)
          }
        },
        :service_instance => {
          :delete_ok => true,
          :create_for => lambda { |service_binding|
            Models::ServiceInstance.make(:space => service_binding.space)
          }
        }
      }
    }

    describe "the service credentials encryption" do
      before do
        VCAP::CloudController::Config.stub(:db_encryption_key).and_return("correct-key")
      end

      let!(:service_binding) do
        Models::ServiceBinding.make(:service_instance => service_instance)
      end

      let(:service_instance) do
        Models::ServiceInstance.make.tap do |instance|
          instance.stub(:service_gateway_client).and_return(
            double("Service Gateway Client",
              :bind => VCAP::Services::Api::GatewayHandleResponse.new(
                :service_id => "gwname_binding",
                :configuration => "abc",
                :credentials => { :password => "the-db-password" }
              )
            )
          )
        end
      end

      it "is encrypted before being written to the database" do
        saved_credentials = Models::ServiceBinding.dataset.naked.last[:credentials]
        saved_credentials.should_not include "the-db-password"
      end

      it "is decrypted when it is read from the database" do
        Models::ServiceBinding.last.credentials["password"].should == "the-db-password"
      end

      it "uses the db_encryption_key from the config file" do
        saved_credentials = Models::ServiceBinding.dataset.naked.last[:credentials]

        expect(
          Encryptor.decrypt(saved_credentials, service_binding.salt)
        ).to include("the-db-password")

        expect {
          VCAP::CloudController::Config.stub(:db_encryption_key).and_return("a-totally-different-key")
          Encryptor.decrypt(saved_credentials, service_binding.salt)
        }.to raise_error(OpenSSL::Cipher::CipherError)
      end

      it "uses a salt, so that every row is encrypted with a different key" do
        credentials = Models::ServiceBinding.dataset.naked.last[:credentials]
        Models::ServiceBinding.make(:service_instance => service_instance)
        other_credentials = Models::ServiceBinding.dataset.naked.last[:credentials]
        expect(credentials.hash).not_to eql(other_credentials.hash)
      end
    end

    describe "bad relationships" do
      before do
        # since we don't set them, these will have different app spaces
        @service_instance = Models::ServiceInstance.make
        @app = Models::App.make
        @service_binding = Models::ServiceBinding.make
      end

      it "should not associate an app with a service from a different app space" do
        expect {
          service_binding = Models::ServiceBinding.make
          service_binding.app = @app
          service_binding.save
        }.to raise_error Models::ServiceBinding::InvalidAppAndServiceRelation
      end

      it "should not associate a service with an app from a different app space" do
        expect {
          service_binding = Models::ServiceBinding.make
          service_binding.service_instance = @service_instance
          service_binding.save
        }.to raise_error Models::ServiceBinding::InvalidAppAndServiceRelation
      end
    end

    describe "binding" do
      let(:gw_client) { double(:client) }

      let(:service) { Models::Service.make }
      let(:service_plan) { Models::ServicePlan.make(:service => service) }
      let(:service_instance) do
        Models::ServiceInstance.new(
          :service_plan => service_plan,
          :name => "my-postgresql",
          :space => Models::Space.make
        )
      end

      let(:provision_resp) do
        VCAP::Services::Api::GatewayHandleResponse.new(
          :service_id => "gwname_instance",
          :configuration => "abc",
          :credentials => { :password => "foo" }
        )
      end

      let(:bind_resp) do
        VCAP::Services::Api::GatewayHandleResponse.new(
          :service_id => "gwname_binding",
          :configuration => "abc",
          :credentials => { :password => "foo" }
        )
      end

      before do
        Models::ServiceInstance.any_instance.stub(:service_gateway_client).and_return(gw_client)
        gw_client.stub(:provision).and_return(provision_resp)
        service_instance.save
      end

      context "service binding" do
        it "should bind a service on the gw during create" do
          VCAP::CloudController::SecurityContext.
            should_receive(:current_user_email).
            and_return("a@b.c")
          gw_client.should_receive(:bind).
            with(hash_including(:email => "a@b.c")).
            and_return(bind_resp)
          binding = Models::ServiceBinding.make(:service_instance => service_instance)
          binding.gateway_name.should == "gwname_binding"
          binding.gateway_data.should == "abc"
          binding.credentials.should == { "password" => "foo" }
        end

        it "should unbind a service on rollback after create" do
          expect {
            Models::ServiceInstance.db.transaction do
              gw_client.should_receive(:bind).and_return(bind_resp)
              gw_client.should_receive(:unbind)
              binding = Models::ServiceBinding.make(:service_instance => service_instance)
              raise "something bad"
            end
          }.to raise_error
        end

        it "should not unbind a service on rollback after update" do
          gw_client.should_receive(:bind).and_return(bind_resp)
          binding = Models::ServiceBinding.make(:service_instance => service_instance)

          expect {
            Models::ServiceInstance.db.transaction do
              binding.update(:name => "newname")
              raise "something bad"
            end
          }.to raise_error
        end
      end

      context "service unbinding" do
        it "should unbind a service on destroy" do
          gw_client.should_receive(:bind).and_return(bind_resp)
          binding = Models::ServiceBinding.make(:service_instance => service_instance)

          gw_client.should_receive(:unbind).with(:service_id => "gwname_instance",
                                                 :handle_id => "gwname_binding",
                                                 :binding_options => {})
          binding.destroy
        end
      end
    end

    describe "restaging" do
      let(:app) do
        app = Models::App.make
        fake_app_staging(app)
        app
      end

      let(:service_instance) { Models::ServiceInstance.make(:space => app.space) }

      it "should trigger restaging when creating a binding" do
        Models::ServiceBinding.make(:app => app, :service_instance => service_instance)
        app.needs_staging?.should be_true
      end

      it "should trigger restaging when directly destroying a binding" do
        binding = Models::ServiceBinding.make(:app => app, :service_instance => service_instance)
        fake_app_staging(app)
        app.needs_staging?.should be_false

        binding.destroy
        app.refresh
        app.needs_staging?.should be_true
      end

      it "should trigger restaging when indirectly destroying a binding" do
        binding = Models::ServiceBinding.make(:app => app, :service_instance => service_instance)
        fake_app_staging(app)
        app.needs_staging?.should be_false

        app.remove_service_binding(binding)
        app.needs_staging?.should be_true
      end
    end
  end
end
