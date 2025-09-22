require "rails_helper"

RSpec.describe UpdateOverdueInterestJob, type: :job do
  describe "#perform" do
    it "skips installment payments when updating overdue interest" do
      project = double("Project", interest_rate: 12.0)
      lot = double("Lot", project: project)
      contract_for_installment = double("Contract", applicant_user: double("User"), lot: lot)
      contract_for_other = double("Contract", applicant_user: double("User"), lot: lot)

      installment = double("Payment",
                           id: 1,
                           payment_type: "installment",
                           due_date: Date.yesterday,
                           amount: 100.0,
                           description: "Cuota 1",
                           interest_amount: 0.0,
                           contract: contract_for_installment)

      other = double("Payment",
                     id: 2,
                     payment_type: "reservation",
                     due_date: Date.yesterday - 5,
                     amount: 200.0,
                     description: "Cuota 2",
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
