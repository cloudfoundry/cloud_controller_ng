require 'spec_helper'

describe Steno::Context::Null do
  include_context 'steno context'

  let(:context) { Steno::Context::Null.new }

  it 'stores no data' do
    expect(context.data).to eq({})
    context.data['foo'] = 'bar'
    expect(context.data).to eq({})
  end
end

describe Steno::Context::ThreadLocal do
  include_context 'steno context'

  let(:context) { Steno::Context::ThreadLocal.new }

  it 'stores data local to threads' do
    b1 = Barrier.new
    b2 = Barrier.new

    t1 = Thread.new do
      context.data['thread'] = 't1'
      b1.release
      b2.wait
      expect(context.data['thread']).to eq('t1')
    end

    t2 = Thread.new do
      b1.wait
      expect(context.data['thread']).to be_nil
      context.data['thread'] = 't2'
      b2.release
    end

    t1.join
    t2.join
  end
end

describe Steno::Context::FiberLocal do
  include_context 'steno context'

  let(:context) { Steno::Context::FiberLocal.new }

  it 'stores data local to fibers' do
    f2 = Fiber.new do
      expect(context.data['fiber']).to be_nil
      context.data['fiber'] = 'f2'
    end

    f1 = Fiber.new do
      context.data['fiber'] = 'f1'
      f2.resume
      expect(context.data['fiber']).to eq('f1')
    end

    f1.resume
  end
end
