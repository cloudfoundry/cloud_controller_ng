shared_examples_for 'a blob' do
  it 'returns a public_download_url' do
    expect(subject.public_download_url).to match(URI.regexp)
  end

  it 'returns a internal_download_url' do
    expect(subject.internal_download_url).to match(URI.regexp)
  end

  it 'returns attributes' do
    expect(subject.attributes('some_key')).to eq({})
  end
end
