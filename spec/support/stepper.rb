# This class is used to instrument and test concurrent behaviour of our code.
# It helps finding race-conditions, DB deadlocks and lock timeouts.
#
# To use it, you'll need to instrument some of your methods with steps before and after.
# Usually, you’ll need to instrument database calls or calls to 3rd party services.
# For example:
#
#   let(:stepper) { Stepper.new(self) }
#
#   before do
#     stepper.instrument(
#       ServiceBroker, :update,
#       before: 'step 1 before - Update service broker',
#       after: 'step 2 after - Update service broker'
#     )
#
#     stepper.instrument(
#       ServiceBrokerState, :update,
#       after: 'step 3 after - Update service broker state'
#     )
#   end
#
# You can also capture the result of the call and add additional instrumentation there:
#
#   stepper.instrument(
#     ServiceBroker, :create,
#     before: 'step 1',
#     after: 'step 2'
#   ) do |broker|
#     stepper.instrument(
#       broker, :update,
#       after: 'step 3'
#     )
#   end
#
# Then you'll need to generate few tests with different orders of execution interleaved:
#
#   20.times.do |i|
#     it 'does the right thing - #{i}' do
#       stepper.start_thread([
#         'step 1 before - Update service broker',
#         'step 2 after - Update service broker',
#         'step 3 after - Update service broker state',
#       ]) { subject.update(message) }
#
#       stepper.start_thread([
#         'step 1 before - Update service broker',
#         'step 2 after - Update service broker',
#         'step 3 after - Update service broker state',
#       ]) { subject.update(message2) }
#
#       stepper.interleave_order
#       stepper.print_order       # for info/debug purposes
#       stepper.run
#
#       expect(stepper.errors).to be_empty
#       expect(stepper.steps_left).to be_empty
#
#       # .. plus more domain-specific expectations ..
#     end
#   end
#
# Use #print_order to make sure you understand in which scenario there is a race condition.
# Use #start_thread to start the thread and specify expected order of defined steps
#   if it were to run independently.
# Use #run to start the actual testing (will #join all created threads)
# Finally, verify that there were no #errors
#   and that all steps were executed asserting on #steps_left.
#
# When running the test, you’ll see the output similar to the following:
#
#   ====
#   [1] start create broker transaction
#   [1] finish create broker and start create broker state
#   [0] start create broker transaction
#   [1] finish create broker transaction
#   [0] finish create broker and start create broker state
#   [0] finish create broker transaction
#   ====
#
#   expecting [0] start create broker transaction
#   expecting [1] start create broker transaction
#   done [1] start create broker transaction
#   expecting [1] finish create broker and start create broker state
#   done [1] finish create broker and start create broker state
#   expecting [1] finish create broker transaction
#   done [0] start create broker transaction
#   done [1] finish create broker transaction
#   expecting [0] finish create broker and start create broker state
#   done [0] finish create broker and start create broker state
#   expecting [0] finish create broker transaction
#   done [0] finish create broker transaction
#
# This can help you identify what’s happening when there is a timeout, deadlock or race condition.
# It also may help to reduce the lock timeout to 5s (in MySQL) to catch them much quicker on dev machine.
class Stepper
  MAX_RETRIES = 1500
  attr_reader :errors

  def initialize(example)
    @example = example
    @defined_orders = []
    @starts = []
    @threads = []
    @expected_order = []
    @errors = []
    @aborted = false
    @mutex = Mutex.new
  end

  def instrument(target, method_name, before: nil, after: nil, &block)
    example.allow(target).
      to example.receive(method_name).
        and_wrap_original do |m, *args, **kwargs, &block|
      step(before) if before
      result = m.call(*args, **kwargs, &block)
      step(after) if after
      block.call(result) if block
      result
    end
  end

  def start_thread(order, &block)
    name = defined_orders.size.to_s
    order_with_thread_name = order.map { |step| "[#{name}] #{step}" }
    defined_orders << order_with_thread_name
    starts << block
  end

  def interleave_order
    @expected_order = []
    while defined_orders.any? { |order| !order.empty? }
      choice = defined_orders.reject(&:empty?).sample
      @expected_order << choice.shift
    end
  end

  def print_order
    puts
    puts '===='
    puts expected_order
    puts '===='
    puts
  end

  def run
    starts.each_with_index do |block, index|
      thread = Thread.start do
        sleep 0.01
        block.call
      rescue => e
        puts e
        abort!
        errors << e
      end

      thread.name = index.to_s
      threads << thread
    end

    threads.each(&:join)
  end

  def step(message, &block)
    full_message = "[#{Thread.current.name}] #{message}"
    puts("expecting #{full_message}")

    retries = 0
    sleep(0.01) while top_expected_message != full_message && (retries += 1) < MAX_RETRIES && !aborted

    raise "Step #{full_message} has reached max #{retries} retries" if retries >= MAX_RETRIES

    raise 'Aborted' if aborted

    advance_to_next_message
    block.call if block

    puts("done #{full_message}")
  end

  def abort!
    @aborted = true
  end

  def steps_left
    expected_order
  end

  private

  attr_reader :aborted, :mutex, :example, :defined_orders, :starts, :threads, :expected_order

  def top_expected_message
    mutex.lock
    result = expected_order.first
    mutex.unlock
    result
  end

  def advance_to_next_message
    mutex.lock
    expected_order.shift
    mutex.unlock
  end

end