require 'spec_helper'

RSpec.describe 'be_a_response_like matcher' do
  it 'passes when two hashes are identical' do
    expect({ 'a' => 1 }).to be_a_response_like({ 'a' => 1 })
  end

  context 'with regular expression matching' do
    it 'passes when comparing a string' do
      expect({ 'a' => '1' }).to be_a_response_like({ 'a' => /\d+/ })
    end

    it 'fails when comparing an integer' do
      expect {
        expect({ 'a' => 1 }).to be_a_response_like({ 'a' => /\d+/ })
      }.to raise_expectation_not_met_with_keys(bad_keys: ['a'])
    end
  end

  it 'fails when values do not match in a top-level key' do
    expect {
      expect({ 'a' => 1 }).to be_a_response_like({ 'a' => 2 })
    }.to raise_expectation_not_met_with_keys(bad_keys: ['a'])
  end

  it 'fails when values do not match in a nested key' do
    expect {
      expect({ 'a' => { 'b' => 1 } }).to be_a_response_like({ 'a' => { 'b' => 2 } })
    }.to raise_expectation_not_met_with_keys(bad_keys: ['a'])
  end

  it 'fails when expected contains a key missing in actual' do
    expect {
      expect({}).to be_a_response_like({ 'a' => 1 })
    }.to raise_expectation_not_met_error(expected: '{"a"=>1}', actual: '{}')
  end

  it 'fails when actual contains a key missing in expected' do
    expect {
      expect({ 'a' => 1 }).to be_a_response_like({})
    }.to raise_expectation_not_met_error(expected: '{}', actual: '{"a"=>1}')
  end

  it 'fails when hash values within arrays do not match' do
    expect {
      expect({ 'a' => [{ 'b' => 1 }] }).to be_a_response_like({ 'a' => [{ 'b' => 2 }] })
    }.to raise_expectation_not_met_error(expected: '{"a"=>[{"b"=>2}]}', actual: '{"a"=>[{"b"=>1}]}')
  end

  it 'fails when hash keys within arrays do not match' do
    expect {
      expect({ 'a' => [{ 'b' => 1 }] }).to be_a_response_like({ 'a' => [{ 'c' => 1 }] })
    }.to raise_expectation_not_met_error(expected: '{"a"=>[{"c"=>1}]}', actual: '{"a"=>[{"b"=>1}]}')
  end

  it 'fails when actual is empty but expected is an empty array' do
    expect {
      expect({}).to be_a_response_like({ 'a' => [] })
    }.to raise_expectation_not_met_error(expected: '{"a"=>[]}', actual: '{}')
  end

  it 'fails when actual as a non-empty but expected is an empty array' do
    expect {
      expect({ 'a' => [{ 'b' => 1 }] }).to be_a_response_like({ 'a' => [] })
    }.to raise_expectation_not_met_error(expected: '{"a"=>[]}', actual: '{"a"=>[{"b"=>1}]}')
  end

  it 'fails on deeply nested value mismatches' do
    expect {
      expect({ 'a' => [{ 'a' => { 'a' => [{ 'a' => 1 }, { 'b' => 2 }] } }] }).to be_a_response_like({ 'a' => [{ 'a' => { 'a' => [{ 'a' => 1 }, { 'b' => 1 }] } }] })
    }.to raise_expectation_not_met_error(expected: '{"a"=>[{"a"=>{"a"=>[{"a"=>1}, {"b"=>1}]}}]}', actual: '{"a"=>[{"a"=>{"a"=>[{"a"=>1}, {"b"=>2}]}}]}')
  end

  def raise_expectation_not_met_error(expected:, actual:)
    raise_error(RSpec::Expectations::ExpectationNotMetError,
      /expected: #{Regexp.escape(expected)}\s*got:\s*#{Regexp.escape(actual)}/)
  end

  def raise_expectation_not_met_with_keys(bad_keys: [])
    keys = bad_keys.map { |key| "\"#{key}\"" }.join(',')
    raise_error(RSpec::Expectations::ExpectationNotMetError,
      /Bad keys: \[#{Regexp.escape(keys)}\]/)
  end
end
