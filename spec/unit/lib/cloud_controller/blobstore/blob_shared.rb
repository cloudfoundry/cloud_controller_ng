shared_examples_for 'a blob' do
  it 'returns a download_url' do
    expect(subject.download_url).to match(URI.regexp)
  end

  it 'returns attributes' do
    expect(subject.attributes('some_key')).to eq({})
  end
end
