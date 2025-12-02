require "spec_helper"

describe Delayed::Backend::Sequel::Job do
  before do
    SimpleJob.runs = 0
    described_class.delete_all
  end
  after do
    Delayed::Worker.reset
    Time.zone = nil
  end

  it_should_behave_like "a delayed_job backend"

  it "does not allow more than 1 worker to grab the same job" do
    expect do
      jobs_to_run = 200
      workers_to_run = 20
      jobs_per_worker = jobs_to_run/workers_to_run

      jobs_to_run.times do
        described_class.create(payload_object: SimpleJob.new)
      end

      workers_to_run.times.map do |i|
        Thread.new do
          worker = Delayed::Worker.new
          worker.name = "worker_#{i}"

          # Ensure each worker performs the expected number of jobs as
          # `work_off` will ocassionally perform less than the requested number
          # if it is unable to lock a job within the `worker.read_ahead` limit
          jobs_completed_by_this_worker = 0
          while jobs_completed_by_this_worker < jobs_per_worker do
            successes, failures = worker.work_off(jobs_per_worker - jobs_completed_by_this_worker)
            expect(failures).to eq(0), "Expected zero failures, got #{failures}"
            jobs_completed_by_this_worker += successes
          end
        end
      end.map(&:join)
    end.not_to raise_error

    expect(Delayed::Job.count).to eql 0
  end

  context ".count" do
    context "NewRelic sampler compat" do
      it "allow count with conditions" do
        described_class.create(failed_at: Time.now)
        expect do
          expect(
            Delayed::Job.count(:conditions => "failed_at is not NULL")
          ).to eq 1
          expect(
            Delayed::Job.count(:conditions => "locked_by is not NULL")
          ).to eq 0
        end.to_not raise_error
      end

      it "allow count with group and conditions" do
        described_class.create(queue: "slow", priority: 2)
        described_class.create(queue: "important", priority: 1)
        expect do
          expect(
            Delayed::Job.count(:group => "queue", :conditions => ['run_at < ? and failed_at is NULL', Time.now])
          ).to match_array [["slow", 1], ["important", 1]]
          expect(
            Delayed::Job.count(:group => "priority", :conditions => ['run_at < ? and failed_at is NULL', Time.now])
          ).to match_array [[1, 1], [2, 1]]
        end.to_not raise_error
      end
    end
  end

  context "db_time_now" do
    it "should return time in current time zone if set" do
      Time.zone = "Eastern Time (US & Canada)"
      expect(
        %w(EST EDT)
      ).to include(Delayed::Job.db_time_now.zone)
    end

    it "should return UTC time if that is the Sequel.database_timezone default" do
      Time.zone = nil
      Sequel.database_timezone = :utc
      expect(
        Delayed::Backend::Sequel::Job.db_time_now.zone
      ).to eql "UTC"
    end

    it "should return local time if that is the AR default" do
      Time.zone = "Central Time (US & Canada)"
      Sequel.database_timezone = :local
      expect(
        %w(CST CDT)
      ).to include(Delayed::Backend::Sequel::Job.db_time_now.zone)
    end
  end

  describe "before_fork" do
    it "should call disconnect on the connection" do
      expect( Sequel::Model.db ).to receive(:disconnect)
      Delayed::Backend::Sequel::Job.before_fork
    end
  end

  describe "enqueue" do
    it "should allow enqueue hook to modify job at DB level" do
      later = described_class.db_time_now + 20.minutes
      job = Delayed::Backend::Sequel::Job.enqueue :payload_object => EnqueueJobMod.new
      expect(
        Delayed::Backend::Sequel::Job[job.id].run_at
      ).to be_within(1).of(later)
    end
  end
end

describe Delayed::Backend::Sequel::Job, "override table name" do
  it "allows to override the table name" do
    ::Sequel::Model.db.transaction :rollback => :always do
      begin
        DB.create_table :another_delayed_jobs do
          primary_key :id
          Integer :priority, :default => 0
          Integer :attempts, :default => 0
          String  :handler, :text => true
          String  :last_error, :text => true
          Time    :run_at
          Time    :locked_at
          Time    :failed_at
          String  :locked_by
          String  :queue
          Time    :created_at
          Time    :updated_at
          index   [:priority, :run_at]
        end
        change_table_name :another_delayed_jobs

        expect( Delayed::Job.table_name ).to eql :another_delayed_jobs
      ensure
        change_table_name nil
        # Replace described_class with reloaded
        self.class.metadata[:described_class] = ::Delayed::Backend::Sequel::Job
      end
    end
  end

  def change_table_name(name)
    ::DelayedJobSequel.table_name = name
    ::Delayed::Backend::Sequel.send :remove_const, :Job
    load File.expand_path(
      "../../../../lib/delayed/backend/sequel.rb",
      __FILE__
    )
    ::Delayed::Worker.backend = :sequel
  end
end
