# Copyright (c) 2009-2012 VMware, Inc.

require "spec_helper"

module VCAP::CloudController
  describe VCAP::CloudController::DeaClient do
    let(:app) { Models::App.make(:droplet_hash => "sha") }
    let(:message_bus) { double(:message_bus) }
    let(:dea_pool) { double(:dea_pool) }
    let(:number_service_instances) { 3 }
    let(:schemata_droplet_response) { Schemata::Dea.mock_find_droplet_response }

    before do
      Models::ServiceBinding.any_instance.stub(:bind_on_gateway)

      number_service_instances.times do
        instance = Models::ServiceInstance.make(:space => app.space)
        binding = Models::ServiceBinding.make(:app => app,
                                              :service_instance => instance)
        app.add_service_binding(binding)
      end

      DeaClient.configure(config, message_bus, dea_pool)
    end

    after { Models::ServiceBinding.any_instance.unstub(:bind_on_gateway) }

    describe "update_uris" do
      subject { DeaClient.update_uris(app) }

      it "does not update deas if app isn't staged" do
        app.update(:package_state => "PENDING")
        message_bus.should_not_receive(:publish)
        subject
      end

      it "sends a dea update message" do
        app.update(:package_state => "STAGED")
        message_bus.should_receive(:publish).with(
          "dea.update",
          json_match(
            hash_including(
              # XXX: change this to actual URLs from user once we do it
              "droplet"   => app.guid,
              "uris"      => app.uris,
              "V1" => {
                "droplet" => app.guid,
                "uris"    => app.uris
              }
            )
          ),
        )
        subject
      end
    end

    describe "#start_instances_with_message" do
      let(:indices) { [1] }
      let(:message_override) { {} }
      let(:start_instances) do
        with_em_and_thread do
          DeaClient.start_instances_with_message(app, indices, message_override)
        end
      end

      subject { start_instances }

      context "when there is a dea id" do
        before { dea_pool.should_receive(:find_dea) { "abc" } }

        it "should send a start messages to deas with message override" do
          #app.instances = 2

          message_bus.should_receive(:publish).with(
              "dea.abc.start",
              json_match(hash_including("V1"))
          )
          subject
        end

        describe "the basic start app fields" do
          subject do
            return_json = nil
            message_bus.stub(:publish).with(any_args) { |_, json| return_json = json }
            start_instances
            Yajl::Parser.parse(return_json)
          end

          it { should be_kind_of Hash }
          its(['droplet']) { should eq app.guid }
          its(['runtime_info']) { should be_kind_of Hash }
          its(['runtime_info']) { should have_key 'name' }
          its(['limits']) { should be_kind_of Hash }
          its(['env']) { should be_kind_of Array }
          its(['console']) { should eq false }
          its(['services']) { should be_kind_of Array }

          it 'has all the services in the hash' do
            expect(subject['services'].count).to eq number_service_instances
          end

          it 'each services is a hash' do
            expect(subject['services'].first).to be_kind_of Hash
          end

          context "with an app enabled for console support" do
            before { app.update(:console => true) }
            its(['console']) { should eq true }
          end
        end

        context 'when there is a message override' do
          let(:message_override) { {'name' => "bar"} }

          it "merges the message override into the message" do
            message_bus.should_receive(:publish).with(anything, json_match(hash_including(message_override)))
            subject
          end
        end
      end

      context 'when there are multiple indices' do
        let(:indices) { [0, 1, 2] }

        it "creates a message for each index" do
          dea_pool.should_receive(:find_dea).exactly(indices.size).times { "abc" }
          message_bus.should_receive(:publish).exactly(indices.size).times
          subject
        end
      end

      context "when there is no dea id" do
        let(:logger) { mock("Logger Mock") }

        before do
          dea_pool.stub(:find_dea) { nil }
          DeaClient.stub(:logger) { logger }
        end

        it "logs an error message" do
          logger.should_receive(:error).with /no resources/
          subject
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
              "version"   => app.version,
              "indices"   => [0, 2],
              "V1"        => {
                "droplet" => app.guid,
                "version" => app.version,
                "indices" => [0, 2]
              }
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
              "instances"   => ["a", "b"],
              "V1" => {
                  "droplet"   => app.guid,
                  "instances" => ["a", "b"]
              }
            )
          ),
        ) do |_, payload|
          Yajl::Parser.parse(payload).should_not include("version")
        end
          with_em_and_thread do
            DeaClient.stop_instances(app, ["a", "b"])
          end
      end
    end

    describe "stop" do
      it "should send a stop messages to deas" do
        app.instances = 2
        message_bus.should_receive(:publish).with(
          "dea.stop",
            json_match(
              hash_including(
                "droplet" => app.guid,
                "V1" => {
                  "droplet" => app.guid
                }
            )
          )
        )

        with_em_and_thread do
          DeaClient.stop(app)
        end
      end
    end

    describe "find_specific_instance" do
      it "should find a specific instance" do
        app.should_receive(:guid).and_return("1")

        instance_message = Schemata::Dea.mock_find_droplet_response
        instance_json = instance_message.encode

        request_hash = { :droplet => "1", :version => "version-1" }
        encoded = Yajl::Encoder.encode(
          { "V1" => request_hash, "min_version" => 1 }.merge(request_hash)
        )

        message_bus.should_receive(:request).
          with("dea.find.droplet", encoded, {:timeout=>2}).
          and_return([instance_json])

        with_em_and_thread do
          DeaClient.find_specific_instance(app, :version => request_hash[:version])
          .contents.should == instance_message.contents
        end
      end
    end

    describe "find_instances" do
      it "should use specified message options" do
        app.should_receive(:guid).and_return("1")
        app.should_receive(:instances).and_return(2)

        instance_message = Schemata::Dea.mock_find_droplet_response
        instance_json = instance_message.encode

        request_hash = { :droplet => "1", :states => ["RUNNING"] }
        encoded = Yajl::Encoder.encode(
          { "V1" => request_hash, "min_version" => 1 }.merge(request_hash)
        )

        message_bus.should_receive(:request).
          with("dea.find.droplet", encoded, { :expected => 2, :timeout => 2 }).
          and_return([instance_json, instance_json])

        message_options = {
          :states => ["RUNNING"]
        }

        with_em_and_thread do
          DeaClient.find_instances(app, message_options).each do |instance|
            instance.contents.should == instance_message.contents
          end
        end
      end

      it "should use default values for expected instances and timeout if none are specified" do
        app.should_receive(:guid).and_return("1")
        app.should_receive(:instances).and_return(2)

        instance_message = Schemata::Dea.mock_find_droplet_response
        instance_json = instance_message.encode

        request_hash = { :droplet => "1" }
        encoded = Yajl::Encoder.encode(
          { "V1" => request_hash, "min_version" => 1 }.merge(request_hash)
        )

        message_bus.should_receive(:request).
          with("dea.find.droplet", encoded, { :expected => 2, :timeout => 2 }).
          and_return([instance_json, instance_json])

        with_em_and_thread do
          DeaClient.find_instances(app).each do |instance|
            instance.contents.should == instance_message.contents
          end
        end
      end

      it "should use the specified values for expected instances and timeout" do
        app.should_receive(:guid).and_return("1")

        instance_message = Schemata::Dea.mock_find_droplet_response
        instance_json = instance_message.encode

        request_hash = { "droplet" => "1", "indices" => [0, 1] }
        encoded = Yajl::Encoder.encode(
          { "V1" => request_hash, "min_version" => 1}.merge(request_hash)
        )

        message_bus.should_receive(:request).
          with("dea.find.droplet", encoded, { :expected => 5, :timeout => 10 }).
          and_return([instance_json, instance_json])

        with_em_and_thread do
          DeaClient.find_instances(app, { :indices => [0, 1] },
                                   { :expected => 5, :timeout => 10 }).
                                   each do |instance|
            instance.contents.should == instance_message.contents
          end
        end
      end
    end

    describe "get_file_uri_for_instance" do
      include Errors

      it "returns the file uri if the required instance is found via DEA v1" do
        app.instances = 2
        app.should_receive(:stopped?).once.and_return(false)
        schemata_droplet_response.file_uri_v2 = nil

        message_bus.should_receive(:request).with(
            "dea.find.droplet",
            json_match(hash_including("V1" => anything, "min_version" => 1)),
            {:timeout =>2}
        ).and_return([schemata_droplet_response.encode])

        with_em_and_thread do
          result = DeaClient.get_file_uri_for_instance(app, "test", 1)
          expect(result.file_uri_v1).to match /#{schemata_droplet_response.file_uri}\/.+?\/test/
          expect(result.file_uri_v2).to be_nil
          expect(result.credentials).to eq schemata_droplet_response.credentials
        end
      end

      it "should return both file_uri_v2 and file_uri_v1 from DEA v2" do
        app.instances = 2
        app.should_receive(:stopped?).once.and_return(false)

        message_bus.should_receive(:request).with(
            "dea.find.droplet",
            json_match(hash_including("V1" => anything, "min_version" => 1)),
            {:timeout =>2}
        ).and_return([schemata_droplet_response.encode])

        with_em_and_thread do
          result = DeaClient.get_file_uri_for_instance(app, "test", 1)
          expect(result.file_uri_v1).to match /#{schemata_droplet_response.file_uri}\/.+?\/test/
          expect(result.file_uri_v2).to eq schemata_droplet_response.file_uri_v2
          expect(result.credentials).to eq schemata_droplet_response.credentials
        end
      end

      context 'when an error occurs' do
        it "should raise an error if the app is in stopped state" do
          app.instances = 1
          app.should_receive(:stopped?).and_return(true)

          instance = 0
          path = "test"

          with_em_and_thread do
            expect {
              DeaClient.get_file_uri_for_instance(app, path, instance)
            }.to raise_error { |error|
              error.should be_an_instance_of Errors::FileError

              msg = "File error: Request failed for app: #{app.name}"
              msg << " path: #{path} as the app is in stopped state."

              expect(error.message).to eq msg
            }
          end
        end

        it "should raise an error if the instance is out of range" do
          app.instances = 5

          instance = 10
          path = "test"

          with_em_and_thread do
            expect {
              DeaClient.get_file_uri_for_instance(app, path, instance)
            }.to raise_error { |error|
              error.should be_an_instance_of Errors::FileError

              msg = "File error: Request failed for app: #{app.name}"
              msg << ", instance: #{instance} and path: #{path} as the instance is"
              msg << " out of range."

              expect(error.message).to eq msg
            }
          end
        end

        it "should raise an error if the instance is not found" do
          app.instances = 2
          app.should_receive(:stopped?).once.and_return(false)

          instance = 1
          path = "test"

          message_bus.should_receive(:request).with(any_args).and_return([])

          with_em_and_thread do
            expect {
              DeaClient.get_file_uri_for_instance(app, path, instance)
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
    end

    describe "get_file_uri_for_instance_id" do
      include Errors

      it "should raise an error if the app is in stopped state" do
        app.should_receive(:stopped?).once.and_return(true)

        instance_id = "abcdef"
        path = "test"

        with_em_and_thread do
          expect {
            DeaClient.get_file_uri_for_instance_id(app, path, instance_id)
          }.to raise_error { |error|
            error.should be_an_instance_of Errors::FileError

            msg = "File error: Request failed for app: #{app.name}"
            msg << " path: #{path} as the app is in stopped state."

            error.message.should == msg
          }
        end
      end

      it "should return the file uri if the required instance is found via DEA v1" do
        app.instances = 2
        app.should_receive(:stopped?).once.and_return(false)

        schemata_droplet_response.file_uri_v2 = nil
        message_bus.should_receive(:request).with(
            "dea.find.droplet",
            json_match(hash_including("V1" => anything, "min_version" => 1)),
            {:timeout =>2}
        ).and_return([schemata_droplet_response.encode])

        with_em_and_thread do
          result = DeaClient.get_file_uri_for_instance_id(app, "test", "abcdef")
          expect(result.file_uri_v1).to match /#{schemata_droplet_response.file_uri}\/.+?\/test/
          expect(result.file_uri_v2).to be_nil
          expect(result.credentials).to eq schemata_droplet_response.credentials
        end
      end

      it "should return both file_uri_v2 and file_uri_v1 from DEA v2" do
        app.instances = 2
        app.should_receive(:stopped?).once.and_return(false)

        message_bus.should_receive(:request).with(
            "dea.find.droplet",
            json_match(hash_including("V1" => anything, "min_version" => 1)),
            {:timeout =>2}
        ).and_return([schemata_droplet_response.encode])

        with_em_and_thread do
          result = DeaClient.get_file_uri_for_instance_id(app, "test", "abcdef")
          expect(result.file_uri_v1).to match /#{schemata_droplet_response.file_uri}\/.+\/test/
          expect(result.file_uri_v2).to eq schemata_droplet_response.file_uri_v2
          expect(result.credentials).to eq schemata_droplet_response.credentials
        end
      end

      it "should raise an error if the instance_id is not found" do
        app.instances = 2
        app.should_receive(:stopped?).once.and_return(false)

        message_bus.should_receive(:request).with(any_args).and_return([])

        with_em_and_thread do
          expect {
            DeaClient.get_file_uri_for_instance_id(app, "test", "abcdef")
          }.to raise_error { |error|
            error.should be_an_instance_of Errors::FileError

            msg = "File error: Request failed for app: #{app.name}"
            msg << ", instance_id: #{"abcdef"} and path: #{"test"} as the instance_id is"
            msg << " not found."

            error.message.should == msg
          }
        end
      end
    end

    describe "find_stats" do
      include Errors

      it "should raise an error if the app is not allowed to be in stopped state" do
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

      it "should return an empty hash if the app is allowed to be in stopped state" do
        app.should_receive(:stopped?).once.and_return(true)

        with_em_and_thread do
          DeaClient.find_stats(app, :allow_stopped_state => true).should == {}
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

        stats = Schemata::Dea.mock_find_droplet_response.stats

        instance_0 = Schemata::Dea.mock_find_droplet_response
        instance_0.index = 0
        instance_0.state = "RUNNING"
        instance_0.stats = stats

        instance_1 = Schemata::Dea.mock_find_droplet_response
        instance_1.index = 1
        instance_1.state = "RUNNING"
        instance_1.stats = stats

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

        stats = Schemata::Dea.mock_find_droplet_response.stats
        instance = Schemata::Dea.mock_find_droplet_response
        instance.index = 0
        instance.state = "RUNNING"
        instance.stats = stats

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

        stats = Schemata::Dea.mock_find_droplet_response.stats
        instance_0 = Schemata::Dea.mock_find_droplet_response
        instance_0.index = -1
        instance_0.state = "RUNNING"
        instance_0.stats = stats

        instance_1 = Schemata::Dea.mock_find_droplet_response
        instance_1.index = 0
        instance_1.state = "RUNNING"
        instance_1.stats = stats

        instance_2 = Schemata::Dea.mock_find_droplet_response
        instance_2.index = 2
        instance_2.state = "RUNNING"
        instance_2.stats = stats

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

        starting_instance = Schemata::Dea.mock_find_droplet_response
        starting_instance.index = 1
        starting_instance.state = "STARTING"
        starting_instance.state_timestamp = 2.0
        starting_instance.debug_ip = "1.2.3.4"
        starting_instance.debug_port = 1001
        starting_instance.console_ip = "1.2.3.5"
        starting_instance.console_port = 1002

        running_instance = Schemata::Dea.mock_find_droplet_response
        running_instance.index = 2
        running_instance.state = "RUNNING"
        running_instance.state_timestamp = 3.0
        running_instance.debug_ip = "2.3.4.5"
        running_instance.debug_port = 2001
        running_instance.console_ip = "2.3.4.6"
        running_instance.console_port = 2002

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

        starting_instance  = Schemata::Dea.mock_find_droplet_response
        starting_instance.index = -1  # -1 is out of range.
        starting_instance.state_timestamp = 1.0
        starting_instance.debug_ip = "1.2.3.4"
        starting_instance.debug_port = 1001
        starting_instance.console_ip = "1.2.3.5"
        starting_instance.console_port = 1002

        running_instance  = Schemata::Dea.mock_find_droplet_response
        running_instance.index = 2  # 2 is out of range.
        running_instance.state = "RUNNING"
        running_instance.state_timestamp = 2.0
        running_instance.debug_ip = "2.3.4.5"
        running_instance.debug_port = 2001
        running_instance.console_ip = "2.3.4.6"
        running_instance.console_port = 2002

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
