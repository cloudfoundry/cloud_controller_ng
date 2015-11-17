shared_examples_for 'a droplet lifecycle receipt presenter' do
  it 'can return a result hash' do
    expect(subject.result(VCAP::CloudController::DropletModel.new)).to be_a(Hash)
  end

  it 'can return links' do
    expect(subject.links(VCAP::CloudController::DropletModel.new)).to be_a(Hash)
  end
end
