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

  describe "#update_uris" do
    it "does not update deas if app isn't staged" do
      app.update(:package_state => "PENDING")
      message_bus.should_not_receive(:publish)
      DeaClient.update_uris(app)
    end

    it "sends a dea update message" do
      app.update(:package_state => "STAGED")
      message_bus.should_receive(:publish).with(
        "dea.update",
        json_match(
          hash_including(
            # XXX: change this to actual URLs from user once we do it
            "uris" => kind_of(Array),
          )
        ),
      )
      DeaClient.update_uris(app)
    end
  end

  describe "#start_instances_with_message" do
    it "should send a start messages to deas with message override" do
      app.instances = 2

      dea_pool.should_receive(:find_dea).and_return("abc")
      message_bus.should_receive(:publish).with(
        "dea.abc.start",
        json_match(
          hash_including(
            "foo"   => "bar",
            "index" => 1,
          )
        ),
      )
      with_em_and_thread do
        DeaClient.start_instances_with_message(app, [1], :foo => "bar")
      end
    end
  end

  describe "start" do
    it "should send start messages to deas" do
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

  describe "#stop_instances" do
    it "should send stop messages to deas" do
      app.instances = 3
      message_bus.should_receive(:publish).with(
        "dea.stop",
        json_match(
          hash_including(
            "droplet"   => app.guid,
            "indices"   => [0, 2],
          )
        ),
      )
      with_em_and_thread do
        DeaClient.stop_instances(app, [0,2])
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

  describe "find_specific_instance" do
    it "should find a specific instance" do
      app.should_receive(:guid).and_return(1)

      instance_json = "\"instance\""
      encoded = Yajl::Encoder.encode({"droplet" => 1, "other_opt" => "value"})
      message_bus.should_receive(:request).with("dea.find.droplet", encoded, {})
        .and_return([instance_json])

      with_em_and_thread do
        DeaClient.find_specific_instance(app, { :other_opt => "value" })
          .should == "instance"
      end
    end
  end

  describe "find_instances" do
    it "should find all instances" do
      app.should_receive(:guid).and_return(1)
      app.should_receive(:instances).and_return(2)

      instance_json = "\"instance\""
      encoded = Yajl::Encoder.encode({"droplet" => 1, "other_opt" => "value"})
      message_bus.should_receive(:request).
        with("dea.find.droplet", encoded, {:expected => 2, :timeout => 2}).
        and_return([instance_json, instance_json])

      with_em_and_thread do
        DeaClient.find_instances(app, { :other_opt => "value" })
          .should == ["instance", "instance"]
      end
    end
  end

  describe "get_file_url" do
    include VCAP::CloudController::Errors

    it "should raise an error if the app is in stopped state" do
      app.should_receive(:stopped?).once.and_return(true)

      instance = 10
      path = "test"

      with_em_and_thread do
        expect {
          DeaClient.get_file_url(app, instance, path)
        }.to raise_error { |error|
          error.should be_an_instance_of FileError

          msg = "File error: Request failed for app: #{app.name}"
          msg << ", instance: #{instance} and path: #{path}"
          msg << " as the app is in stopped state."

          error.message.should == msg
        }
      end
    end

    it "should raise an error if the instance is out of range" do
      app.should_receive(:stopped?).once.and_return(false)
      app.instances = 5

      instance = 10
      path = "test"

      with_em_and_thread do
        expect {
          DeaClient.get_file_url(app, instance, path)
        }.to raise_error { |error|
          error.should be_an_instance_of FileError

          msg = "File error: Request failed for app: #{app.name}"
          msg << ", instance: #{instance} and path: #{path} as the instance is"
          msg << " out of range."

          error.message.should == msg
        }
      end
    end

    it "should return the file url if the required instance is found" do
      app.instances = 2
      app.should_receive(:stopped?).once.and_return(false)

      instance = 1
      path = "test"

      search_options = {
        :indices => [instance],
        :states => [:STARTING, :RUNNING, :CRASHED],
        :version => app.version
      }

      instance_found = {
        :file_uri => "file_uri",
        :staged => "staged",
        :credentials => "credentials"
      }

      DeaClient.should_receive(:find_specific_instance).once
        .with(app, search_options).and_return(instance_found)

      with_em_and_thread do
        file_url, credentials = DeaClient.get_file_url(app, instance, path)
        file_url.should == "file_uristaged/test"
        credentials.should == "credentials"
      end
    end

    it "should raise an error if the instance is not found" do
      app.instances = 2
      app.should_receive(:stopped?).once.and_return(false)

      instance = 1
      path = "test"

      search_options = {
        :indices => [instance],
        :states => [:STARTING, :RUNNING, :CRASHED],
        :version => app.version
      }

      DeaClient.should_receive(:find_specific_instance).once
        .with(app, search_options).and_return(nil)

      with_em_and_thread do
        expect {
          DeaClient.get_file_url(app, instance, path)
        }.to raise_error { |error|
          error.should be_an_instance_of FileError

          msg = "File error: Request failed for app: #{app.name}"
          msg << ", instance: #{instance} and path: #{path} as the instance is"
          msg << " not found."

          error.message.should == msg
        }
      end
    end
  end

  describe "find_stats" do
    include VCAP::CloudController::Errors

    it "should raise an error if the app is in stopped state" do
      app.should_receive(:stopped?).once.and_return(true)

      with_em_and_thread do
        expect {
          DeaClient.find_stats(app)
        }.to raise_error { |error|
          error.should be_an_instance_of StatsError

          msg = "Stats error: Request failed for app: #{app.name}"
          msg << " as the app is in stopped state."

          error.message.should == msg
        }
      end
    end

    it "should return the stats for all instances" do
      app.instances = 2
      app.should_receive(:stopped?).once.and_return(false)

      search_options = {
        :include_stats => true,
        :states => [:RUNNING],
        :version => app.version,
      }

      stats = double("mock stats")
      instance_0 = {
        :index => 0,
        :state => "RUNNING",
        :stats => stats,
      }

      instance_1 = {
        :index => 1,
        :state => "RUNNING",
        :stats => stats,
      }

      DeaClient.should_receive(:find_instances).once
        .with(app, search_options).and_return([instance_0, instance_1])

      with_em_and_thread do
        app_stats = DeaClient.find_stats(app)
        app_stats.should == {
          0 => {
            :state => "RUNNING",
            :stats => stats,
          },
          1 => {
            :state => "RUNNING",
            :stats => stats,
          },
        }
      end
    end

    it "should return filler stats for instances that have not responded" do
      app.instances = 2
      app.should_receive(:stopped?).once.and_return(false)

      search_options = {
        :include_stats => true,
        :states => [:RUNNING],
        :version => app.version,
      }

      stats = double("mock stats")
      instance = {
        :index => 0,
        :state => "RUNNING",
        :stats => stats,
      }

      Time.should_receive(:now).once.and_return(1)

      DeaClient.should_receive(:find_instances).once
        .with(app, search_options).and_return([instance])

      with_em_and_thread do
        app_stats = DeaClient.find_stats(app)
        app_stats.should == {
          0 => {
            :state => "RUNNING",
            :stats => stats,
          },
          1 => {
            :state => "DOWN",
            :since => 1,
          },
        }
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
