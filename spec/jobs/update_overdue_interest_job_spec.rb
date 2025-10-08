# frozen_string_literal: true

require 'rails_helper'
# spec/jobs/update_overdue_interest_job_spec.rb
# RSpec tests for UpdateOverdueInterestJob to ensure it skips installment payments.
RSpec.describe UpdateOverdueInterestJob, type: :job do
  describe '#perform' do
    it 'only processes payments that accrue interest (installment, full, advance)' do
      project = double('Project', interest_rate: 12.0)
      lot = double('Lot', project:)
      contract_for_installment = double('Contract', applicant_user: double('User'), lot:)
      contract_for_reservation = double('Contract', applicant_user: double('User'), lot:)

      # Stub ledger_entries for contracts to support find_or_initialize_by(...).update!
      fake_ledger_for_installment = double('LedgerRelation')
      ledger_entry_double = double('LedgerEntry', update!: true)
      allow(contract_for_installment).to receive(:ledger_entries).and_return(fake_ledger_for_installment)

      # reservation contract ledger should not be touched in this scenario
      allow(contract_for_reservation).to receive(:ledger_entries).and_return(double)

      installment = double('Payment',
                           id: 1,
                           payment_type: 'installment',
                           due_date: Date.yesterday - 5,
                           amount: 100.0,
                           description: 'Cuota 1',
                           interest_amount: 0.0,
                           contract: contract_for_installment)

      reservation = double('Payment',
                           id: 2,
                           payment_type: 'reservation',
                           due_date: Date.yesterday - 5,
                           amount: 200.0,
                           description: 'Reserva',
                           interest_amount: 0.0,
                           contract: contract_for_reservation)

      # The AR query should return only payments that accrue interest (installment, full, advance).
      allow(Payment).to receive_message_chain(:joins, :where, :where).and_return([installment])

      # Allow the job to call notify_overdue_interest on the payment doubles
      allow(installment).to receive(:notify_overdue_interest)
      allow(reservation).to receive(:notify_overdue_interest)

      # The job uses with_lock on payments; make the double yield into the block
      allow(installment).to receive(:with_lock).and_yield

      # Expect the payment interest_amount to be updated and an interest ledger entry to be upserted
      expect(fake_ledger_for_installment).to receive(:find_or_initialize_by).with(hash_including(payment: installment,
                                                                                                 entry_type: 'interest')).and_return(ledger_entry_double)
      expect(installment).to receive(:update!).with(hash_including(:interest_amount))
      expect(reservation).not_to receive(:update!)

      described_class.new.perform
    end
  end
end
