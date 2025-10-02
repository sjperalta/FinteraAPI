# frozen_string_literal: true

require 'rails_helper'
# spec/jobs/update_overdue_interest_job_spec.rb
# RSpec tests for UpdateOverdueInterestJob to ensure it skips installment payments.
RSpec.describe UpdateOverdueInterestJob, type: :job do
  describe '#perform' do
    it 'skips installment payments when updating overdue interest' do
      project = double('Project', interest_rate: 12.0)
      lot = double('Lot', project:)
      contract_for_installment = double('Contract', applicant_user: double('User'), lot:)
      contract_for_other = double('Contract', applicant_user: double('User'), lot:)

      # Stub ledger_entries for contracts
      allow(contract_for_installment).to receive(:ledger_entries).and_return(double(create!: true))
      allow(contract_for_other).to receive(:ledger_entries).and_return(double(create!: true))

      installment = double('Payment',
                           id: 1,
                           payment_type: 'installment',
                           due_date: Date.yesterday,
                           amount: 100.0,
                           description: 'Cuota 1',
                           interest_amount: 0.0,
                           contract: contract_for_installment)

      other = double('Payment',
                     id: 2,
                     payment_type: 'reservation',
                     due_date: Date.yesterday - 5,
                     amount: 200.0,
                     description: 'Cuota 2',
                     interest_amount: 0.0,
                     contract: contract_for_other)

      relation = [installment, other]

      # Stub the complete ActiveRecord query chain: joins -> where -> where.not
      allow(Payment).to receive_message_chain(:joins, :where, :where, :not).and_return(relation)

      # Allow the job to call notify_overdue_interest on the payment doubles
      allow(installment).to receive(:notify_overdue_interest)
      allow(other).to receive(:notify_overdue_interest)

      expect(installment).not_to receive(:update!)
      expect(other).to receive(:update!)

      described_class.new.perform
    end
  end
end
