# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)

module VCAP::CloudController
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
        res[:env].should be_kind_of(Array)
        res[:console].should == false
      end

      context "with an app enabled for console support" do
        it "should enable console in the start message" do
          app.update(:console => true)
          res = DeaClient.send(:start_app_message, app)
          res[:console].should == true
        end
      end
    end

    describe "update_uris" do
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

    describe "start_instances_with_message" do
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

      it "sends a dea start message that includes cc_partition" do
        config_override(
          :cc_partition => "ngFTW",
        )
        DeaClient.configure(config, message_bus, dea_pool)

        app.instances = 1
        dea_pool.should_receive(:find_dea).and_return("abc")
        message_bus.should_receive(:publish).with("dea.abc.start", anything) do |_, json|
          Yajl::Parser.parse(json).should include("cc_partition" => "ngFTW")
        end

        with_em_and_thread do
          DeaClient.start(app)
        end
      end
    end

    describe "stop_indices" do
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
            DeaClient.stop_indices(app, [0,2])
          end
      end
    end

    describe "stop_instances" do
      it "should send stop messages to deas" do
        app.instances = 3
        message_bus.should_receive(:publish).with(
          "dea.stop",
          json_match(
            hash_including(
              "droplet"   => app.guid,
              "instances"   => ["a", "b"]
            )
          ),
        )
          with_em_and_thread do
            DeaClient.stop_instances(app, ["a", "b"])
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
        message_bus.should_receive(:request).with("dea.find.droplet", encoded, {}).
          and_return([instance_json])

        with_em_and_thread do
          DeaClient.find_specific_instance(app, { :other_opt => "value" })
          .should == "instance"
        end
      end
    end

    describe "find_instances" do
      it "should use specified message options" do
        app.should_receive(:guid).and_return(1)
        app.should_receive(:instances).and_return(2)

        instance_json = "\"instance\""
        encoded = Yajl::Encoder.encode({
          "droplet" => 1,
          "other_opt_0" => "value_0",
          "other_opt_1" => "value_1",
        })
        message_bus.should_receive(:request).
          with("dea.find.droplet", encoded, { :expected => 2, :timeout => 2 }).
          and_return([instance_json, instance_json])

        message_options = {
          :other_opt_0 => "value_0",
          :other_opt_1 => "value_1",
        }

        with_em_and_thread do
          DeaClient.find_instances(app, message_options).
            should == ["instance", "instance"]
        end
      end

      it "should use default values for expected instances and timeout if none are specified" do
        app.should_receive(:guid).and_return(1)
        app.should_receive(:instances).and_return(2)

        instance_json = "\"instance\""
        encoded = Yajl::Encoder.encode({ "droplet" => 1 })
        message_bus.should_receive(:request).
          with("dea.find.droplet", encoded, { :expected => 2, :timeout => 2 }).
          and_return([instance_json, instance_json])

        with_em_and_thread do
          DeaClient.find_instances(app).
            should == ["instance", "instance"]
        end
      end

      it "should use the specified values for expected instances and timeout" do
        app.should_receive(:guid).and_return(1)

        instance_json = "\"instance\""
        encoded = Yajl::Encoder.encode({ "droplet" => 1, "other_opt" => "value" })
        message_bus.should_receive(:request).
          with("dea.find.droplet", encoded, { :expected => 5, :timeout => 10 }).
          and_return([instance_json, instance_json])

        with_em_and_thread do
          DeaClient.find_instances(app, { :other_opt => "value" },
                                   { :expected => 5, :timeout => 10 }).
                                   should == ["instance", "instance"]
        end
      end
    end

    describe "get_file_uri" do
      include Errors

      it "should raise an error if the app is in stopped state" do
        app.should_receive(:stopped?).once.and_return(true)

        instance = 10
        path = "test"

        with_em_and_thread do
          expect {
            DeaClient.get_file_uri(app, instance, path)
          }.to raise_error { |error|
            error.should be_an_instance_of Errors::FileError

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
            DeaClient.get_file_uri(app, instance, path)
          }.to raise_error { |error|
            error.should be_an_instance_of Errors::FileError

            msg = "File error: Request failed for app: #{app.name}"
            msg << ", instance: #{instance} and path: #{path} as the instance is"
            msg << " out of range."

            error.message.should == msg
          }
        end
      end

      it "should return the file uri if the required instance is found via DEA v1" do
        app.instances = 2
        app.should_receive(:stopped?).once.and_return(false)

        instance = 1
        path = "test"

        search_options = {
          :indices => [instance],
          :states => [:STARTING, :RUNNING, :CRASHED],
          :version => app.version,
          :path => "test",
        }

        instance_found = {
          :file_uri => "file_uri",
          :staged => "staged",
          :credentials => ["username", "password"],
        }

        DeaClient.should_receive(:find_specific_instance).
          with(app, search_options).and_return(instance_found)

        with_em_and_thread do
          info = DeaClient.get_file_uri(app, instance, path)
          info.should be_an_instance_of Hash
          info[:uri].should == "file_uristaged/test"
          info[:file_uri_v2].should be_false
          info[:credentials].should == ["username", "password"]
        end
      end

      it "should return the file uri from DEA v2 if the required instance is found via DEA v2 as well as v1" do
        app.instances = 2
        app.should_receive(:stopped?).once.and_return(false)

        instance = 1
        path = "test"

        search_options = {
          :indices => [instance],
          :states => [:STARTING, :RUNNING, :CRASHED],
          :version => app.version,
          :path => "test",
        }

        instance_found = {
          :file_uri_v2 => "file_uri_v2",
          :file_uri => "file_uri",
          :staged => "staged",
          :credentials => ["username", "password"],
        }

        DeaClient.should_receive(:find_specific_instance).
            with(app, search_options).and_return(instance_found)

        with_em_and_thread do
          info = DeaClient.get_file_uri(app, instance, path)
          info.should be_an_instance_of Hash
          info[:uri].should == "file_uri_v2"
          info[:file_uri_v2].should be_true
          info.keys.should_not include(:credentials)
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
          :version => app.version,
          :path => "test",
        }

        DeaClient.should_receive(:find_specific_instance).
            with(app, search_options).and_return(nil)

        with_em_and_thread do
          expect {
            DeaClient.get_file_uri(app, instance, path)
          }.to raise_error { |error|
            error.should be_an_instance_of Errors::FileError

            msg = "File error: Request failed for app: #{app.name}"
            msg << ", instance: #{instance} and path: #{path} as the instance is"
            msg << " not found."

            error.message.should == msg
          }
        end
      end
    end

    describe "find_stats" do
      include Errors

      it "should raise an error if the app is in stopped state" do
        app.should_receive(:stopped?).once.and_return(true)

        with_em_and_thread do
          expect {
            DeaClient.find_stats(app)
          }.to raise_error { |error|
            error.should be_an_instance_of Errors::StatsError

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

        DeaClient.should_receive(:find_instances).
            with(app, search_options).and_return([instance_0, instance_1])

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

        DeaClient.should_receive(:find_instances).
          with(app, search_options).and_return([instance])

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

      it "should return filler stats for instances with out of range indices" do
        app.instances = 2
        app.should_receive(:stopped?).once.and_return(false)

        search_options = {
          :include_stats => true,
          :states => [:RUNNING],
          :version => app.version,
        }

        stats = double("mock stats")
        instance_0 = {
          :index => -1,
          :state => "RUNNING",
          :stats => stats,
        }

        instance_1 = {
          :index => 0,
          :state => "RUNNING",
          :stats => stats,
        }

        instance_2 = {
          :index => 2,
          :state => "RUNNING",
          :stats => stats,
        }

        Time.should_receive(:now).and_return(1)

        DeaClient.should_receive(:find_instances).
          with(app, search_options).and_return([instance_0,
                                                instance_1,
                                                instance_2])

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

    describe "find_all_instances" do
      include Errors

      it "should raise an error if the app is in stopped state" do
        app.should_receive(:stopped?).once.and_return(true)

        expected_msg = "Instances error: Request failed for app: #{app.name}"
        expected_msg << " as the app is in stopped state."

        with_em_and_thread do
          expect {
            DeaClient.find_all_instances(app)
          }.to raise_error(Errors::InstancesError, expected_msg)
        end
      end

      it "should return flapping instances" do
        app.instances = 2
        app.should_receive(:stopped?).and_return(false)

        search_options = {
          :state => :FLAPPING,
          :version => app.version
        }

        flapping_instances = {
          :indices => [
            { :index => 0, :since => 1},
            { :index => 1, :since => 2},
          ],
        }

        HealthManagerClient.should_receive(:find_status).
            with(app, search_options).and_return(flapping_instances)

        # Should not find starting or running instances if all instances are
        # flapping.
        DeaClient.should_not_receive(:find_instances)

        with_em_and_thread do
          app_instances = DeaClient.find_all_instances(app)
          app_instances.should == {
            0 => {
              :state => "FLAPPING",
              :since => 1,
            },
            1 => {
              :state => "FLAPPING",
              :since => 2,
            },
          }
        end
      end

      it "should ignore out of range indices of flapping instances" do
        app.instances = 2
        app.should_receive(:stopped?).and_return(false)

        search_options = {
          :state => :FLAPPING,
          :version => app.version,
        }

        flapping_instances = {
          :indices => [
            { :index => -1, :since => 1 },  # -1 is out of range.
            { :index => 2, :since => 2 },  # 2 is out of range.
          ],
        }

        HealthManagerClient.should_receive(:find_status).
            with(app, search_options).and_return(flapping_instances)

        search_options = {
          :states => [:STARTING, :RUNNING],
          :version => app.version,
        }

        DeaClient.should_receive(:find_instances).
          with(app, search_options, { :expected => 2 }).
          and_return([])

        Time.should_receive(:now).twice.and_return(1)

        with_em_and_thread do
          app_instances = DeaClient.find_all_instances(app)
          app_instances.should == {
            0 => {
              :state => "DOWN",
              :since => 1,
            },
            1 => {
              :state => "DOWN",
              :since => 1,
            },
          }
        end
      end

      it "should return starting or running instances" do
        app.instances = 3
        app.should_receive(:stopped?).and_return(false)

        search_options = {
          :state => :FLAPPING,
          :version => app.version,
        }

        flapping_instances = {
          :indices => [
            { :index => 0, :since => 1 },
          ],
        }

        HealthManagerClient.should_receive(:find_status).
          with(app, search_options).and_return(flapping_instances)

        search_options = {
          :states => [:STARTING, :RUNNING],
          :version => app.version,
        }

        starting_instance  = {
          :index => 1,
          :state => "STARTING",
          :state_timestamp => 2,
          :debug_ip => "1.2.3.4",
          :debug_port => 1001,
          :console_ip => "1.2.3.5",
          :console_port => 1002,
        }

        running_instance  = {
          :index => 2,
          :state => "RUNNING",
          :state_timestamp => 3,
          :debug_ip => "2.3.4.5",
          :debug_port => 2001,
          :console_ip => "2.3.4.6",
          :console_port => 2002,
        }

        DeaClient.should_receive(:find_instances).
          with(app, search_options, { :expected => 2 }).
          and_return([starting_instance, running_instance])

        with_em_and_thread do
          app_instances = DeaClient.find_all_instances(app)
          app_instances.should == {
            0 => {
              :state => "FLAPPING",
              :since => 1,
            },
            1 => {
              :state => "STARTING",
              :since => 2,
              :debug_ip => "1.2.3.4",
              :debug_port => 1001,
              :console_ip => "1.2.3.5",
              :console_port => 1002,
            },
            2 => {
              :state => "RUNNING",
              :since => 3,
              :debug_ip => "2.3.4.5",
              :debug_port => 2001,
              :console_ip => "2.3.4.6",
              :console_port => 2002,
            },
          }
        end
      end

      it "should ignore out of range indices of starting or running instances" do
        app.instances = 2
        app.should_receive(:stopped?).and_return(false)

        search_options = {
          :state => :FLAPPING,
          :version => app.version,
        }

        HealthManagerClient.should_receive(:find_status).
          with(app, search_options)

        search_options = {
          :states => [:STARTING, :RUNNING],
          :version => app.version,
        }

        starting_instance  = {
          :index => -1,  # -1 is out of range.
          :state_timestamp => 1,
          :debug_ip => "1.2.3.4",
          :debug_port => 1001,
          :console_ip => "1.2.3.5",
          :console_port => 1002,
        }

        running_instance  = {
          :index => 2,  # 2 is out of range.
          :state => "RUNNING",
          :state_timestamp => 2,
          :debug_ip => "2.3.4.5",
          :debug_port => 2001,
          :console_ip => "2.3.4.6",
          :console_port => 2002,
        }

        DeaClient.should_receive(:find_instances).
          with(app, search_options, { :expected => 2 }).
          and_return([starting_instance, running_instance])

        Time.should_receive(:now).twice.and_return(1)

        with_em_and_thread do
          app_instances = DeaClient.find_all_instances(app)
          app_instances.should == {
            0 => {
              :state => "DOWN",
              :since => 1,
            },
            1 => {
              :state => "DOWN",
              :since => 1,
            },
          }
        end
      end

      it "should return fillers for instances that have not responded" do
        app.instances = 2
        app.should_receive(:stopped?).and_return(false)

        search_options = {
          :state => :FLAPPING,
          :version => app.version,
        }

        HealthManagerClient.should_receive(:find_status).
          with(app, search_options)

        search_options = {
          :states => [:STARTING, :RUNNING],
          :version => app.version,
        }

        DeaClient.should_receive(:find_instances).
          with(app, search_options, { :expected => 2 }).
          and_return([])

        Time.should_receive(:now).twice.and_return(1)

        with_em_and_thread do
          app_instances = DeaClient.find_all_instances(app)
          app_instances.should == {
            0 => {
              :state => "DOWN",
              :since => 1,
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
end
