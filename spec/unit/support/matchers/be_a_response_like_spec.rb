require 'spec_helper'

RSpec.describe 'be_a_response_like matcher' do
  it 'passes when two hashes are identical' do
    expect({ 'a' => 1 }).to be_a_response_like({ 'a' => 1 })
  end

  it 'passes with array values' do
    expect({ 'a' => [1, 2] }).to be_a_response_like({ 'a' => [1, 2] })
  end

  context 'with regular expression matching' do
    it 'passes when comparing a string' do
      expect({ 'a' => '1' }).to be_a_response_like({ 'a' => /\d+/ })
    end

    it 'fails when comparing an integer' do
      expect {
        expect({ 'a' => 1 }).to be_a_response_like({ 'a' => /\d+/ })
      }.to raise_expectation_not_met_with_summary_parts('! a:', '- /\d+/', '+ 1')
    end

    it 'passes when matching an iso8601 timestamp' do
      expect({ 'a' => Time.now.utc.strftime('%Y-%m-%dT%H:%M:%SZ') }).to be_a_response_like({ 'a' => iso8601 })
    end

    it 'does not interpret strings as regex' do
      expect {
        expect({ 'a' => '[thing]' }).to be_a_response_like({ 'a' => '[th]' })
      }.to raise_expectation_not_met_with_summary_parts('! a:', '- [th]', '+ [thing]')
    end
  end

  it 'fails when values do not match in a top-level key' do
    expect {
      expect({ 'a' => 1 }).to be_a_response_like({ 'a' => 2 })
    }.to raise_expectation_not_met_with_summary_parts('! a:', '- 2', '+ 1')
  end

  it 'fails when values do not match in a nested key' do
    expect {
      expect({ 'a' => { 'b' => 1 } }).to be_a_response_like({ 'a' => { 'b' => 2 } })
    }.to raise_expectation_not_met_with_summary_parts('! a.b:', '- 2', '+ 1')
  end

  it 'fails when expected contains a key missing in actual' do
    expect {
      expect({}).to be_a_response_like({ 'a' => 1 })
    }.to raise_expectation_not_met_with_summary(/- a: 1/)
  end

  it 'fails when actual contains a key missing in expected' do
    expect {
      expect({ 'a' => 1 }).to be_a_response_like({})
    }.to raise_expectation_not_met_with_summary(/\+ a: 1/)
  end

  it 'fails when array values do not match' do
    expect {
      expect({ 'a' => [1, 2] }).to be_a_response_like({ 'a' => [1] })
    }.to raise_expectation_not_met_with_summary(/\+ a\[1\]: 2/)
  end

  it 'fails when array values are permuted' do
    expect {
      expect({ 'a' => [1, 2] }).to be_a_response_like({ 'a' => [2, 1] })
    }.to raise_expectation_not_met_with_summary(/\+ a\[0\]: 1\n\s+- a\[2\]: 1/)
  end

  it 'fails when hash values within arrays do not match' do
    expect {
      expect({ 'a' => [{ 'b' => 1 }] }).to be_a_response_like({ 'a' => [{ 'b' => 2 }] })
    }.to raise_expectation_not_met_with_key_change(expected: '- a[0]: {"b"=>2}', actual: '+ a[0]: {"b"=>1}')
  end

  it 'fails when hash keys within arrays do not match' do
    expect {
      expect({ 'a' => [{ 'b' => 1 }] }).to be_a_response_like({ 'a' => [{ 'c' => 1 }] })
    }.to raise_expectation_not_met_with_key_change(expected: '- a[0]: {"c"=>1}', actual: '+ a[0]: {"b"=>1}')
  end

  it 'fails when actual is empty but expected is an empty array' do
    expect {
      expect({}).to be_a_response_like({ 'a' => [] })
    }.to raise_expectation_not_met_with_summary(/- a: \[\]/)
  end

  it 'fails when actual as a non-empty but expected is an empty array' do
    expect {
      expect({ 'a' => [{ 'b' => 1 }] }).to be_a_response_like({ 'a' => [] })
    }.to raise_expectation_not_met_with_summary(/\+ a\[0\]: \{"b"=>1\}/)
  end

  it 'fails on deeply nested value mismatches' do
    expect {
      expect({ 'a' => [{ 'a' => { 'a' => [{ 'a' => 1 }, { 'b' => 2 }] } }] }).to be_a_response_like({ 'a' => [{ 'a' => { 'a' => [{ 'a' => 1 }, { 'b' => 1 }] } }] })
    }.to raise_expectation_not_met_with_key_change(expected: '- a[0].a.a[1]: {"b"=>1}',
                                                   actual:   '+ a[0].a.a[1]: {"b"=>2}')
  end

  def raise_expectation_not_met_with_summary(ptn)
    raise_error(RSpec::Expectations::ExpectationNotMetError, ptn)
  end

  def raise_expectation_not_met_with_key_change(expected:, actual:)
    ptn = Regexp.new(Regexp.escape(expected) + '\n\s+' + Regexp.escape(actual))
    raise_error(RSpec::Expectations::ExpectationNotMetError, ptn)
  end

  def raise_expectation_not_met_with_summary_parts(*parts)
    ptn = Regexp.new(parts.map { |part| Regexp.escape(part) }.join('\n\s+'))
    raise_error(RSpec::Expectations::ExpectationNotMetError, ptn)
  end
end
