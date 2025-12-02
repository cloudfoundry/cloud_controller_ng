require 'spec_helper'

describe Steno::Record do
  let(:message) { Array('test message') }
  let(:record) { Steno::Record.new('test', :info, message) }

  it 'sets the process id' do
    expect(record.process_id).to eq(Process.pid)
  end

  it 'sets the thread id' do
    expect(record.thread_id).to eq(Thread.current.object_id)
  end

  it 'sets the fiber id(if available)', :needs_fibers do
    expect(record.fiber_id).to eq(Fiber.current.object_id)
  end

  it 'sets the source' do
    expect(record.source).to eq('test')
  end

  it 'stringifies the message' do
    expect(record.message).to be_a(String)
  end

  it 'uses a UTC timestamp' do
    expect(record.timestamp.to_f).to be_within(0.1).of(Time.now.utc.to_f)
  end
end
