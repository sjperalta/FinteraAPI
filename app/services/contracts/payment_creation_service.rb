# frozen_string_literal: true

module Contracts
  # Service to handle payment creation for contracts
  class PaymentCreationService
    def initialize(contract)
      @contract = contract
    end

    def call
      case @contract.financing_type
      when 'direct'
        create_direct_payments
      when 'bank', 'cash'
        create_single_payment
      else
        raise "Unknown financing type: #{@contract.financing_type}"
      end
    end

    private

    def create_direct_payments
      project_name = @contract.lot&.project&.name
      contract_date = @contract.created_at&.to_date || Date.current

      # Reservation payment: 15 days after contract creation
      reservation_due_date = contract_date + 15.days
      reservation_payment = Payment.create!(
        contract: @contract,
        description: "Proyecto #{project_name} - Reserva",
        due_date: reservation_due_date,
        amount: @contract.reserve_amount,
        status: 'pending',
        payment_type: 'reservation'
      )
      @contract.ledger_entries.create!(amount: reservation_payment.amount,
                                       description: "Pago por #{reservation_payment.description}",
                                       entry_type: 'reservation', payment: reservation_payment)

      # Down payment: 1 month after reservation
      down_payment_due_date = reservation_due_date + 1.month
      down_payment = Payment.create!(
        contract: @contract,
        description: "Proyecto #{project_name} - Prima",
        due_date: down_payment_due_date,
        amount: @contract.down_payment,
        status: 'pending',
        payment_type: 'down_payment'
      )
      @contract.ledger_entries.create!(amount: down_payment.amount, description: "Pago por #{down_payment.description}",
                                       entry_type: 'down_payment', payment: down_payment)

      # Installments: Start after down payment
      remaining_balance = @contract.amount - @contract.reserve_amount - @contract.down_payment
      monthly_payment = remaining_balance / @contract.payment_term

      @contract.payment_term.times do |i|
        installment_due_date = down_payment_due_date + (i + 1).months
        installment_payment = Payment.create!(
          contract: @contract,
          due_date: installment_due_date,
          description: "Proyecto #{project_name} - Cuota #{i + 1}",
          amount: monthly_payment,
          status: 'pending',
          payment_type: 'installment'
        )
        @contract.ledger_entries.create!(amount: installment_payment.amount,
                                         description: "Pago por #{installment_payment.description}",
                                         entry_type: 'installment', payment: installment_payment)
      end
    end

    def create_single_payment
      project_name = @contract.lot&.project&.name
      remaining_balance = @contract.amount - @contract.reserve_amount

      due_date = Date.today + 15.days
      reservation_payment = Payment.create!(
        contract: @contract,
        description: "Proyecto #{project_name} - Reserva",
        due_date:,
        amount: @contract.reserve_amount,
        status: 'pending',
        payment_type: 'reservation'
      )
      @contract.ledger_entries.create!(amount: reservation_payment.amount,
                                       description: "Pago por #{reservation_payment.description}",
                                       entry_type: 'reservation', payment: reservation_payment)

      full_payment = Payment.create!(
        contract: @contract,
        description: "Proyecto #{project_name} - Contado",
        due_date: due_date.next_month,
        amount: remaining_balance,
        status: 'pending',
        payment_type: 'full'
      )
      @contract.ledger_entries.create!(amount: full_payment.amount, description: "Pago por #{full_payment.description}",
                                       entry_type: 'full', payment: full_payment)
    end
  end
end
