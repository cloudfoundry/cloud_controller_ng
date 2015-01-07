require 'spec_helper'

module VCAP::CloudController
  describe UndoAppChanges do
    let(:state) { 'STARTED' }
    let(:instances) { 2 }
    let(:app) do
      AppFactory.make(package_hash: 'abc',
                      name: 'app-name',
                      droplet_hash: 'I DO NOTHING',
                      state: state,
                      instances: instances,
                      )
    end
    let(:changes) { { updated_at: [1, app.updated_at] } }
    let(:undo_changes) { UndoAppChanges.new(app) }

    describe '#undo' do
      context 'state has changed' do
        it 'should stop an app that has started' do
          changes[:state] = ['STOPPED', 'STARTED']
          undo_changes.undo(changes)
          expect(app.state).to eq('STOPPED')
        end

        it 'does not undo when the final app state does not match the desired app state' do
          app.state = 'CRASHED'
          changes[:state] = ['STARTED', 'STOPPED']
          undo_changes.undo(changes)
          expect(app.state).to eq('CRASHED')
        end

        context('when the app is stopped') do
          let(:state) { 'STOPPED' }

          it 'should not undo any stop' do
            changes[:state] = ['STARTED', 'STOPPED']
            undo_changes.undo(changes)
            expect(app.state).to eq('STOPPED')
          end
        end
      end

      context 'instances have changed' do
        it 'should undo any increase' do
          changes[:instances] = [1, 2]
          undo_changes.undo(changes)
          expect(app.instances).to eq(1)
        end

        it 'should not undo any decrease' do
          changes[:instances] = [3, 2]
          undo_changes.undo(changes)
          expect(app.instances).to eq(2)
        end

        it 'should not undo if the instances do not match' do
          changes[:instances] = [2, 3]
          undo_changes.undo(changes)
          expect(app.instances).to eq(2)
        end
      end

      context 'state and instances changed' do
        it 'should stop an app that has started, and undo any increase' do
          changes[:state] = ['STOPPED', 'STARTED']
          changes[:instances] = [1, 2]
          undo_changes.undo(changes)
          expect(app.instances).to eq(1)
          expect(app.state).to eq('STOPPED')
        end
      end

      context 'no undo if already updated' do
        it 'should not stop an app that has started' do
          changes[:state] = ['STOPPED', 'STARTED']
          changes[:updated_at][1] = changes[:updated_at][1] + 1
          undo_changes.undo(changes)
          expect(app.state).to eq('STARTED')
        end
      end
    end
  end
end
