require 'lightweight_spec_helper'
require 'support/stepper'

RSpec.describe 'Stepper' do
  # make sure randomness is predictable/testable
  let(:random) { Random.new(1234) }

  let(:target) { Target.new }
  subject(:stepper) { Stepper.new(self, random: random) }

  context 'in isolation (#step is mocked out - too much complexity)' do
    before do
      allow(stepper).to receive(:step) do |message, &block|
        target.record(:stepper, :step, message)
        block.call if block
      end
    end

    describe '#instrument' do
      it 'can instrument simple method with before step' do
        stepper.instrument(target, :method_one, before: 'before step one')

        target.method_one

        expect(target.calls).to eq([[:stepper, :step, 'before step one'], [:method_one, '[]']])
      end

      it 'can instrument simple method with after step' do
        stepper.instrument(target, :method_one, after: 'after step one')

        target.method_one

        expect(target.calls).to eq([[:method_one, '[]'], [:stepper, :step, 'after step one']])
      end

      it 'can instrument method with few args with before/after step' do
        stepper.instrument(target, :method_two, before: 'before', after: 'after')

        target.method_two(42, 'hello')

        expect(target.calls).to eq([
          [:stepper, :step, 'before'],
          [:method_two, [42, 'hello'], '[]'],
          [:stepper, :step, 'after']
        ])
      end

      it 'can instrument method with few args and kwargs with before/after step' do
        stepper.instrument(target, :method_three, before: 'before', after: 'after')

        target.method_three(42, 'hello', kwarg1: 'world', kwarg2: 91)

        expect(target.calls).to eq([
          [:stepper, :step, 'before'],
          [:method_three, [42, 'hello'], { kwarg1: 'world', kwarg2: 91 }, '[]'],
          [:stepper, :step, 'after']
        ])
      end

      it 'can instrument method with few args, kwargs and a block with before/after step' do
        stepper.instrument(target, :method_four, before: 'before', after: 'after')

        expected_block = -> {}
        target.method_four(42, 'hello', kwarg1: 'world', kwarg2: 91, &expected_block)

        expect(target.calls).to eq([
          [:stepper, :step, 'before'],
          [:method_four, [42, 'hello'], { kwarg1: 'world', kwarg2: 91 }, expected_block, '[]'],
          [:stepper, :step, 'after']
        ])
      end

      it 'allows to use the value returned by the instrumented method inside of the block' do
        got_value = nil
        stepper.instrument(target, :method_one, before: 'before', after: 'after') do |return_value|
          got_value = return_value
        end

        target.method_one

        expect(got_value).to eq(:some_return_value)
      end
    end

    describe '#start_thread + #interleave_order' do
      it 'can start a single thread, keeps the same order as provided, and uses thread index prefixes' do
        stepper.start_thread([
          'step 1',
          'step 2',
          'step 3'
        ]) do
          fail('should not run before #run is called')
        end

        stepper.interleave_order

        expect(stepper.steps_left).to eq([
          '[0] step 1',
          '[0] step 2',
          '[0] step 3'
        ])
      end

      it 'can start multiple threads, interleaves the order, and uses thread index prefixes' do
        stepper.start_thread([
          'step 1a',
          'step 2a',
          'step 3a'
        ]) do
          fail('should not run before #run is called')
        end

        stepper.start_thread([
          'step 1b',
          'step 2b',
          'step 3b'
        ]) do
          fail('should not run before #run is called')
        end

        stepper.start_thread([
          'step 1c',
          'step 2c',
          'step 3c'
        ]) do
          fail('should not run before #run is called')
        end

        stepper.interleave_order

        expect(stepper.steps_left).to eq([
          '[2] step 1c',
          '[1] step 1b',
          '[0] step 1a',
          '[0] step 2a',
          '[0] step 3a',
          '[2] step 2c',
          '[2] step 3c',
          '[1] step 2b',
          '[1] step 3b'
        ])
      end
    end

    describe '#run' do
      it 'runs a single thread when there is one' do
        stepper.instrument(target, :method_one, before: 'step 1', after: 'step 2')
        stepper.instrument(target, :method_two, after: 'step 3')

        error = RuntimeError.new('oopsie')
        stepper.start_thread([
          'step 1',
          'step 2',
          'step 3'
        ]) do
          target.method_one
          raise error
        end

        stepper.interleave_order
        stepper.run

        expect(target.calls).to eq([
          [:stepper, :step, 'step 1'],
          [:method_one, '[0]'],
          [:stepper, :step, 'step 2'],
        ])
        expect(stepper.aborted?).to eq(true)
        expect(stepper.errors).to eq([error])
      end

      it 'handles exceptions' do
        stepper.instrument(target, :method_one, before: 'step 1', after: 'step 2')
        stepper.instrument(target, :method_two, after: 'step 3')

        stepper.start_thread([
          'step 1',
          'step 2',
          'step 3'
        ]) do
          target.method_one
          target.method_two(:arg1, :arg2)
        end

        stepper.interleave_order
        stepper.run

        expect(target.calls).to eq([
          [:stepper, :step, 'step 1'],
          [:method_one, '[0]'],
          [:stepper, :step, 'step 2'],
          [:method_two, [:arg1, :arg2], '[0]'],
          [:stepper, :step, 'step 3'],
        ])
      end

      it 'runs multiple threads' do
        stepper.instrument(target, :method_one, before: 'step 1', after: 'step 2')
        stepper.instrument(target, :method_two, after: 'step 3')

        stepper.start_thread([
          'step 1',
          'step 2',
          'step 3'
        ]) do
          target.method_one
          target.method_two(:arg1, :arg2)
        end

        stepper.start_thread([
          'step 1',
          'step 2',
          'step 3'
        ]) do
          target.method_one
          target.method_two(:arg1, :arg2)
        end

        stepper.interleave_order
        stepper.run

        # sort is required here because #step is stubbed out, so
        # the order is not predictable
        expect(target.calls.to_a.sort).to eq([
          [:method_one, '[0]'],
          [:method_one, '[1]'],
          [:method_two, [:arg1, :arg2], '[0]'],
          [:method_two, [:arg1, :arg2], '[1]'],
          [:stepper, :step, 'step 1'],
          [:stepper, :step, 'step 1'],
          [:stepper, :step, 'step 2'],
          [:stepper, :step, 'step 2'],
          [:stepper, :step, 'step 3'],
          [:stepper, :step, 'step 3'],
        ])
        expect(stepper.errors).to be_empty
      end
    end
  end

  context 'in integration (#step is not mocked out)' do
    let(:target) { Target.new }

    before do
      allow(stepper).to receive(:step).and_wrap_original do |original, message, &block|
        original.call(message) do
          target.record(:stepper, :step, message, "[#{Thread.current.name}]")
          block.call if block
        end
      end
    end

    20.times do |i|
      it "runs multiple threads in the interleaved order - #{i}" do
        stepper.instrument(target, :method_one, before: 'step 1', after: 'step 2')
        stepper.instrument(target, :method_two, before: 'step 3', after: 'step 4')

        stepper.start_thread([
          'step 1',
          'step 2',
          'step 3',
          'step 4'
        ]) do
          target.method_one
          target.method_two(:arg1, :arg2)
        end

        stepper.start_thread([
          'step 1',
          'step 2',
          'step 3',
          'step 4'
        ]) do
          target.method_one
          target.method_two(:arg1, :arg2)
        end

        stepper.interleave_order

        expect(stepper.steps_left).to eq([
          '[1] step 1',
          '[1] step 2',
          '[0] step 1',
          '[1] step 3',
          '[0] step 2',
          '[0] step 3',
          '[0] step 4',
          '[1] step 4'
        ])

        stepper.run

        expect(stepper.errors).to be_empty
        expect(target.calls).to eq([
          [:stepper, :step, 'step 1', '[1]'],
          [:method_one, '[1]'],
          [:stepper, :step, 'step 2', '[1]'],

          [:stepper, :step, 'step 1', '[0]'],
          [:method_one, '[0]'],

          [:stepper, :step, 'step 3', '[1]'],
          [:method_two, [:arg1, :arg2], '[1]'],

          [:stepper, :step, 'step 2', '[0]'],
          [:stepper, :step, 'step 3', '[0]'],
          [:method_two, [:arg1, :arg2], '[0]'],
          [:stepper, :step, 'step 4', '[0]'],

          [:stepper, :step, 'step 4', '[1]']
        ])
      end
    end
  end

  class Target
    attr_reader :calls

    def initialize
      @calls = []
      @mutex = Mutex.new
    end

    def method_one
      record(:method_one, "[#{Thread.current.name}]")
      :some_return_value
    end

    def method_two(arg1, arg2)
      record(:method_two, [arg1, arg2], "[#{Thread.current.name}]")
    end

    def method_three(arg1, arg2, kwarg1:, kwarg2:)
      record(:method_three, [arg1, arg2], { kwarg1: kwarg1, kwarg2: kwarg2 }, "[#{Thread.current.name}]")
    end

    def method_four(arg1, arg2, kwarg1:, kwarg2:, &block)
      record(:method_four, [arg1, arg2], { kwarg1: kwarg1, kwarg2: kwarg2 }, block, "[#{Thread.current.name}]")
    end

    def record(*args)
      mutex.lock
      calls << args
      mutex.unlock
    end

    private

    attr_reader :mutex
  end
end
