require 'spec_helper'

describe StructuredError do

  it 'generates the correct hash' do
    exception = described_class.new('some msg', { 'foo' => 'bar' })
    exception.set_backtrace(['/foo:1', '/bar:2'])

    expect(exception.to_h).to eq({
       'description' => "some msg",
       'error' => {
         'types' => ["StructuredError", "StandardError"],
         'backtrace' => ['/foo:1', '/bar:2'],
         'error' => { 'foo' => 'bar' }
       }
    })
  end

end