# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

describe VCAP::CloudController::DeaClient do
  let(:app) { Models::App.make }
  let(:message_bus) { double(:message_bus) }
  let(:dea_pool) { double(:dea_pool) }

  before do
    DeaClient.configure(config, message_bus, dea_pool)

    NUM_SVC_INSTANCES.times do
      instance = Models::ServiceInstance.make(:space => app.space)
      binding = Models::ServiceBinding.make(:app => app,
                                            :service_instance => instance)
      app.add_service_binding(binding)
    end
  end

  describe "start_app_message" do
    NUM_SVC_INSTANCES = 3

    it "should return a serialized dea message" do
      res = DeaClient.send(:start_app_message, app)
      res.should be_kind_of(Hash)
      res[:droplet].should == app.guid
      res[:services].should be_kind_of(Array)
      res[:services].count.should == NUM_SVC_INSTANCES
      res[:services].first.should be_kind_of(Hash)
      res[:limits].should be_kind_of(Hash)
      res[:env].should be_kind_of(Hash)
    end
  end

  describe "start" do
    it "should send a start messages to deas" do
      app.instances = 2
      dea_pool.should_receive(:find_dea).and_return("abc")
      dea_pool.should_receive(:find_dea).and_return("def")
      message_bus.should_receive(:publish).with("dea.abc.start", kind_of(String))
      message_bus.should_receive(:publish).with("dea.def.start", kind_of(String))
      with_em_and_thread do
        DeaClient.start(app)
      end
    end
  end

  describe "stop" do
    it "should send a stop messages to deas" do
      app.instances = 2
      message_bus.should_receive(:publish).with("dea.stop", kind_of(String))
      with_em_and_thread do
        DeaClient.stop(app)
      end
    end
  end

  describe "change_running_instances" do
    context "increasing the instance count" do
      it "should issue a start command with extra indices" do
        dea_pool.should_receive(:find_dea).and_return("abc")
        dea_pool.should_receive(:find_dea).and_return("def")
        dea_pool.should_receive(:find_dea).and_return("efg")
        message_bus.should_receive(:publish).with("dea.abc.start", kind_of(String))
        message_bus.should_receive(:publish).with("dea.def.start", kind_of(String))
        message_bus.should_receive(:publish).with("dea.efg.start", kind_of(String))

        app.instances = 4
        app.save
        with_em_and_thread do
          DeaClient.change_running_instances(app, 3)
        end
      end
    end

    context "decreasing the instance count" do
      it "should stop the higher indices" do
        message_bus.should_receive(:publish).with("dea.stop", kind_of(String))
        app.instances = 5
        app.save
        with_em_and_thread do
          DeaClient.change_running_instances(app, -2)
        end
      end
    end

    context "with no changes" do
      it "should do nothing" do
        app.instances = 9
        app.save
        with_em_and_thread do
          DeaClient.change_running_instances(app, 0)
        end
      end
    end
  end
end
