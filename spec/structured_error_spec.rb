require 'spec_helper'

describe StructuredError do

  it 'generates the correct hash' do
    exception = described_class.new('some msg', :code => 54321, :error => {'foo' => 'bar'})
    exception.set_backtrace(['/foo:1', '/bar:2'])

    expect(exception.to_h).to eq({
      'code' => 54321,
      'description' => "some msg",
      'types' => ["StructuredError", "StandardError"],
      'backtrace' => ['/foo:1', '/bar:2'],
      'source' => {'foo' => 'bar'},
    })
  end

  it 'sets the default error code to 10001' do
    exception = described_class.new('some msg')
    exception.code.should == 10001
  end
end
