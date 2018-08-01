require 'utils/workpool'

RSpec.describe WorkPool do
  it 'runs blocks passed in' do
    wp  = WorkPool.new(1)
    ran = false
    wp.submit do
      ran = true
    end
    wp.drain
    expect(ran).to be_truthy
  end

  it 'propagates arguments passed in to the inner block' do
    wp   = WorkPool.new(1)
    args = []
    wp.submit(1, 2, 3) do |a, b, c|
      args = [a, b, c]
    end
    wp.drain
    expect(args).to eq([1, 2, 3])
  end

  it 'parallelizes up to "size" threads' do
    wp = WorkPool.new(5)

    require 'benchmark'
    time = Benchmark.realtime do
      10.times do
        wp.submit { sleep 0.1 }
      end

      wp.drain
    end

    expect(time).to be_within(0.05).of(0.2)
  end

  it 'finishes running work before draining' do
    wp  = WorkPool.new(1)
    ran = false
    wp.submit do
      sleep 0.1
      ran = true
    end
    expect(ran).to be_falsey
    wp.drain
    expect(ran).to be_truthy
  end
end
