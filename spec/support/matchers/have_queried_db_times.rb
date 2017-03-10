RSpec::Matchers.define :have_queried_db_times do |query_regex, expected_times|
  match do |actual_blk|
    begin
      @matched_calls = []
      execute_fn = '_execute'
      query_at_index = 1
      if Sequel::Model.db.database_type == :mssql
        execute_fn = 'execute'
        query_at_index = 0
      end
      stub = allow(Sequel::Model.db).to receive(execute_fn.to_sym)
      stub.and_call_original
      @calls = stub.and_record_arguments
      actual_blk.call
      @matched_calls = @calls.select { |call| call[query_at_index] =~ query_regex }
      @matched_calls.size == expected_times
    rescue => e
      @raised_exception = e
      false
    ensure
      allow(Sequel::Model.db).to receive(:_execute).and_call_original
    end
  end

  failure_message do |_|
    if @raised_exception
      "Raised exception in the block: #{@raised_exception.inspect}\n#{@raised_exception.backtrace.join("\n")}"
    else
      "Expected exactly #{expected_times} times to query DB for #{query_regex.inspect}, " \
        "but queried DB #{@matched_calls.size} times. " \
        "\n\nAll queries:\n#{@calls.inspect}" \
        "\n\nMatched queries: #{@matched_calls.inspect}"
    end
  end

  def supports_block_expectations?
    true
  end
end
