shared_examples 'steno context' do
  it 'supports clearing context local data' do
    context.data['test'] = 'value'
    context.clear
    expect(context.data['test']).to be_nil
  end
end
