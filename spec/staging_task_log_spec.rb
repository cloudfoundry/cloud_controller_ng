# Copyright (c) 2009-2012 VMware, Inc.

require File.expand_path("../spec_helper", __FILE__)
require "cloud_controller/staging_task_log"

describe VCAP::CloudController::StagingTaskLog do
  before :each do
    @task_id = 'test_task'
    @log = 'Hello'
    @redis_mock = mock("mock redis")
    @task_log = StagingTaskLog.new(@task_id, @log, @redis_mock)
    @task_key = StagingTaskLog.key_for_id(@task_id)
  end

  describe '#save' do
    it 'should set a task result blob in redis' do
      @redis_mock.should_receive(:set).with(@task_key, @task_log.task_log)
      @task_log.save
    end
  end

  describe '#fetch' do
    it 'should fetch and decode an existing task result' do
      @redis_mock.should_receive(:get).with(@task_key).and_return(@log)
      res = StagingTaskLog.fetch(@task_id, @redis_mock)
      res.should be_instance_of(StagingTaskLog)
    end

    it 'should return nil if no key exists' do
      @redis_mock.should_receive(:get).with(@task_key).and_return(nil)
      res = StagingTaskLog.fetch(@task_id, @redis_mock)
      res.should be_nil
    end

    it 'should raise error when redis fetching fails' do
      error = RuntimeError.new("Mock Runtime Error from redis")
      @redis_mock.should_receive(:get).with(@task_key).and_raise(error)
      expect {
        StagingTaskLog.fetch(@task_id, @redis_mock)
      }.to raise_error { |e|
        e.should == error
      }
    end
  end
end
