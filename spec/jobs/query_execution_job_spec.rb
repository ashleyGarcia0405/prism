require 'rails_helper'

RSpec.describe QueryExecutionJob, type: :job do
  let(:organization) { Organization.create!(name: "Test Hospital") }
  let(:user) { organization.users.create!(name: "Test User", email: "test@example.com", password: "password123") }
  let(:dataset) { organization.datasets.create!(name: "Patient Data") }
  let(:query) do
    dataset.queries.create!(
      sql: "SELECT state, AVG(age), COUNT(*) FROM patients GROUP BY state HAVING COUNT(*) >= 25",
      user: user,
      estimated_epsilon: 0.5
    )
  end
  let(:run) { query.runs.create!(user: user, status: 'pending') }

  describe '#perform' do
    context 'successful execution' do
      it 'updates run status to completed' do
        QueryExecutionJob.new.perform(run.id)
        expect(run.reload.status).to eq('completed')
      end

      it 'stores result data' do
        QueryExecutionJob.new.perform(run.id)
        expect(run.reload.result).to be_present
      end

      it 'consumes privacy budget' do
        original_consumed = dataset.privacy_budget.consumed_epsilon
        QueryExecutionJob.new.perform(run.id)

        expect(dataset.privacy_budget.reload.consumed_epsilon).to eq(original_consumed + 0.5)
      end

      it 'stores proof artifacts' do
        QueryExecutionJob.new.perform(run.id)

        artifacts = run.reload.proof_artifacts
        expect(artifacts['mechanism']).to eq('laplace')
        expect(artifacts['noise_scale']).to be_present
        expect(artifacts['epsilon'].to_f).to eq(0.5)
      end

      it 'sets backend_used' do
        QueryExecutionJob.new.perform(run.id)
        expect(run.reload.backend_used).to eq('dp_sandbox')
      end

      it 'sets execution_time_ms' do
        QueryExecutionJob.new.perform(run.id)
        expect(run.reload.execution_time_ms).to be > 0
      end

      it 'logs query_executed audit event' do
        expect {
          QueryExecutionJob.new.perform(run.id)
        }.to change { AuditEvent.where(action: 'query_executed').count }.by(1)
      end

      it 'includes metadata in audit event' do
        QueryExecutionJob.new.perform(run.id)

        event = AuditEvent.where(action: 'query_executed').last
        expect(event.metadata['query_id']).to eq(query.id)
        expect(event.metadata['dataset_id']).to eq(dataset.id)
        expect(event.metadata['epsilon_consumed'].to_f).to eq(0.5)
      end
    end

    context 'when budget is exhausted' do
      before do
        dataset.privacy_budget.update!(consumed_epsilon: 2.8)
      end

      it 'fails the run' do
        QueryExecutionJob.new.perform(run.id)
        expect(run.reload.status).to eq('failed')
      end

      it 'sets error message' do
        QueryExecutionJob.new.perform(run.id)
        expect(run.reload.error_message).to include('privacy budget')
      end

      it 'does not consume budget' do
        original_consumed = dataset.privacy_budget.consumed_epsilon
        QueryExecutionJob.new.perform(run.id)

        expect(dataset.privacy_budget.reload.consumed_epsilon).to eq(original_consumed)
      end

      it 'logs privacy_budget_exhausted audit event' do
        expect {
          QueryExecutionJob.new.perform(run.id)
        }.to change { AuditEvent.where(action: 'privacy_budget_exhausted').count }.by(1)
      end
    end

    context 'when execution fails' do
      before do
        allow_any_instance_of(DpSandbox).to receive(:execute).and_raise(StandardError.new("Execution error"))
      end

      it 'fails the run' do
        expect {
          QueryExecutionJob.new.perform(run.id)
        }.to raise_error(StandardError)

        expect(run.reload.status).to eq('failed')
      end

      it 'rolls back budget reservation' do
        original_consumed = dataset.privacy_budget.consumed_epsilon
        original_reserved = dataset.privacy_budget.reserved_epsilon

        expect {
          QueryExecutionJob.new.perform(run.id)
        }.to raise_error(StandardError)

        budget = dataset.privacy_budget.reload
        expect(budget.consumed_epsilon).to eq(original_consumed)
        expect(budget.reserved_epsilon).to eq(original_reserved)
      end

      it 'logs query_failed audit event' do
        expect {
          begin
            QueryExecutionJob.new.perform(run.id)
          rescue StandardError
            # Expected to raise
          end
        }.to change { AuditEvent.where(action: 'query_failed').count }.by(1)
      end

      it 'includes error in audit metadata' do
        begin
          QueryExecutionJob.new.perform(run.id)
        rescue StandardError
          # Expected to raise
        end

        event = AuditEvent.where(action: 'query_failed').last
        expect(event.metadata['error']).to eq("Execution error")
      end
    end
  end
end
