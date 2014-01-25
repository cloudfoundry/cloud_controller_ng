require "spec_helper"

module VCAP::CloudController
  describe Varz do
    describe "#setup_updates" do
      before do
        @periodic_timer_blks = []
        EM.stub(:add_periodic_timer) do |&blk|
          @periodic_timer_blks << blk
        end
      end

      it "bumps the number of users and sets periodic timer" do
        expect(VCAP::CloudController::Varz).to receive(:bump_user_count).twice
        Varz.setup_updates
        @periodic_timer_blks.map(&:call)
      end

      it "bumps the length of cc job queues and sets periodic timer" do
        expect(VCAP::CloudController::Varz).to receive(:bump_cc_job_queue_length).twice
        Varz.setup_updates
        @periodic_timer_blks.map(&:call)
      end
    end

    describe "#bump_user_count" do
      it "should include the number of users in varz" do
        # We have to use stubbing here because when we run in parallel mode,
        # there might other tests running and create/delete users concurrently.
        VCAP::Component.varz.synchronize do
          VCAP::Component.varz[:cc_user_count] = 0
        end

        4.times{ User.create(guid: SecureRandom.uuid) }
        Varz.bump_user_count

        VCAP::Component.varz.synchronize do
          VCAP::Component.varz[:cc_user_count].should == 4
        end
      end
    end

    describe "#bump_cc_job_queue_length" do
      it "should include the length of the delayed job queue" do
        VCAP::Component.varz.synchronize do
          VCAP::Component.varz[:cc_job_queue_length] = 0
        end

        Delayed::Job.enqueue(Jobs::Runtime::AppBitsPacker.new("abc", "def", []), queue: "cc_local")
        Delayed::Job.enqueue(Jobs::Runtime::AppBitsPacker.new("ghj", "klm", []), queue: "cc_local")
        Delayed::Job.enqueue(Jobs::Runtime::AppBitsPacker.new("abc", "def", []), queue: "cc_generic")

        Varz.bump_cc_job_queue_length

        VCAP::Component.varz.synchronize do
          VCAP::Component.varz[:cc_job_queue_length][:cc_local].should == 2
          VCAP::Component.varz[:cc_job_queue_length][:cc_generic].should == 1
        end
      end

      it "should find jobs which have not been attempted yet" do
        Delayed::Job.enqueue(Jobs::Runtime::AppBitsPacker.new("abc", "def", []), queue: "cc_local")
        Delayed::Job.enqueue(Jobs::Runtime::AppBitsPacker.new("abc", "def", []), queue: "cc_generic")

        Varz.bump_cc_job_queue_length

        VCAP::Component.varz.synchronize do
          expect(VCAP::Component.varz[:cc_job_queue_length][:cc_local]).to eq(1)
          expect(VCAP::Component.varz[:cc_job_queue_length][:cc_generic]).to eq(1)
        end
      end

      it "should ignore jobs that have already been attempted" do
        job = Jobs::Runtime::AppBitsPacker.new("abc", "def", [])
        Delayed::Job.enqueue(job, queue: "cc_generic", attempts: 1)

        Varz.bump_cc_job_queue_length

        VCAP::Component.varz.synchronize do
          expect(VCAP::Component.varz[:cc_job_queue_length]).to eq({})
        end
      end
    end
  end
end