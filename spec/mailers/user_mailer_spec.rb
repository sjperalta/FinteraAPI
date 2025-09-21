require "rails_helper"

RSpec.describe UserMailer, type: :mailer do
  let(:user) { double("User", email: "user@example.com", full_name: "Test User") }
  let(:project) { double("Project", name: "Proyecto Uno") }
  let(:lot) { double("Lot", name: "Lote 1", length: 10, width: 20, project: project) }
  let(:contract) do
    double("Contract",
      id: 42,
      applicant_user: user,
      lot: lot,
      project: project,
      financing_type: "cash",
      payment_term: 12,
      reserve_amount: 1000,
      down_payment: 200,
      created_at: Time.new(2025, 1, 1, 12, 0),
      approved_at: Time.new(2025, 2, 1, 12, 0)
    )
  end

  let(:payment) do
    double("Payment",
      amount: 1500,
      due_date: Date.new(2025, 3, 1),
      approved_at: Date.new(2025, 3, 2),
      contract: contract
    )
  end

  describe "contract_submitted" do
    it "sends to the applicant with translated subject and includes project name" do
      mail = UserMailer.with(user: user, contract: contract).contract_submitted

      expect(mail.to).to eq([user.email])
      expect(mail.subject).to eq(I18n.t("mailers.user_mailer.contract_submitted.subject"))
      expect(mail.body.encoded).to include(contract.lot.project.name)
    end
  end

  describe "contract_approved" do
    it "sends approval email with translated subject and approved date" do
      mail = UserMailer.with(user: user, contract: contract).contract_approved

      expect(mail.to).to eq([user.email])
      expect(mail.subject).to eq(I18n.t("mailers.user_mailer.contract_approved.subject"))
      expect(mail.body.encoded).to include(contract.lot.project.name)
      expect(mail.body.encoded).to include(contract.approved_at.strftime("%d/%m/%Y"))
    end
  end

  describe "payment_approved" do
    it "sends payment approved email with translated subject and amount" do
      mail = UserMailer.with(user: user, payment: payment).payment_approved

      expect(mail.to).to eq([user.email])
      expect(mail.subject).to eq(I18n.t("mailers.user_mailer.payment_approved.subject"))
      expect(mail.body.encoded).to include(ActionController::Base.helpers.number_to_currency(payment.amount))
      expect(mail.body.encoded).to include(payment.due_date.strftime('%d-%m-%Y'))
    end
  end

  describe "overdue_payment_email" do
    it "lists overdue payments and uses translated title" do
      payments = [payment]
      mail = UserMailer.with(user: user, payments: payments).overdue_payment_email

      expect(mail.to).to eq([user.email])
      expect(mail.subject).to eq(I18n.t("mailers.user_mailer.overdue_payment_email.subject"))
      expect(mail.body.encoded).to include(lot.name)
      expect(mail.body.encoded).to include(ActionController::Base.helpers.number_to_currency(payment.amount))
    end
  end

  describe "reservation_approved" do
    it "sends reservation approved email with reservation info" do
      mail = UserMailer.with(user: user, contract: contract).reservation_approved

      expect(mail.to).to eq([user.email])
      expect(mail.subject).to eq(I18n.t("mailers.user_mailer.reservation_approved.subject"))
      expect(mail.body.encoded).to include("##{contract.id}")
      expect(mail.body.encoded).to include(contract.lot.name)
    end
  end

  describe "reset_code_email" do
    it "sends reset code with translated body including the code" do
      mail = UserMailer.with(user: user, code: "ABC123").reset_code_email

      expect(mail.to).to eq([user.email])
      expect(mail.subject).to eq(I18n.t("mailers.user_mailer.reset_code_email.subject"))
      expect(mail.body.encoded).to include("ABC123")
    end
  end

  describe 'reservation_approved' do
    it 'renders the headers and body using translations' do
      I18n.with_locale(:es) do
        email = UserMailer.with(user: user, contract: contract).reservation_approved

        expect(email.to).to eq([user.email])
        expect(email.subject).to eq(I18n.t('mailers.user_mailer.reservation_approved.subject'))
        expect(email.body.encoded).to match(I18n.t('mailers.user_mailer.reservation_approved.title'))
      end
    end
  end
end
