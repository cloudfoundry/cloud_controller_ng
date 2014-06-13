RSpec::Matchers.define :have_queried_db_times do |query_regex, expected_times|
  match do |actual_blk|
    begin
      @calls = []
      @matched_calls = []
      Sequel::Model.db.stub(:_execute).with { |*args| @calls << args; true }.and_call_original
      actual_blk.call
      @matched_calls = @calls.select { |call| call[1] =~ query_regex }
      @matched_calls.size == expected_times
    rescue Exception => e
      @raised_exception = e
      false
    ensure
      Sequel::Model.db.unstub(:_execute)
    end
  end

  failure_message_for_should do |_|
    if @raised_exception
      "Raised exception in the block: #{@raised_exception.inspect}\n#{@raised_exception.backtrace.join("\n")}"
    else
      "Expected exactly #{expected_times} times to query DB for #{query_regex.inspect}, " +
        "but queried DB #{@matched_calls.size} times. " +
        "\n\nAll queries:\n#{@calls.inspect}" +
        "\n\nMatched queries: #{@matched_calls.inspect}"
    end
  end
end
