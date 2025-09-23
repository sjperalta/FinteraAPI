# frozen_string_literal: true

# app/services/release_unpaid_reservation_service.rb

module Contracts
  class ReleaseUnpaidReservationService
    include Notifiable

    def call
      Rails.logger.info 'Starting ReleaseUnpaidReservationService'

      released_contract_ids = Set.new

      Payment.where(payment_type: 'reservation', status: 'pending')
             .where('due_date < ?', Date.today)
             .includes(:contract)
             .find_each do |payment|
        contract = payment.contract
        next unless contract

        # Proceed only if no reservation payment has been processed (i.e. still pending)
        if contract.payments.where(payment_type: 'reservation').where.not(status: 'pending').empty?
          Rails.logger.info "Processing Contract ##{contract.id} (Lot: #{contract.lot.name}) for unpaid reservation."

          # Use AASM events to transition the contract to the cancelled state.
          # First, if the contract isn't in a state to be cancelled,
          # try to reject it first (which transitions from pending/submitted to rejected).
          if contract.may_reject?
            contract.rejection_reason = 'Pago de reserva expiro, el sistema libero este contrato'
            contract.reject!
          end

          # Then, if possible, transition from rejected to cancelled.
          if contract.may_cancel?
            contract.cancel!
            released_contract_ids.add(contract.id)
          else
            Rails.logger.warn "Contract ##{contract.id} cannot be cancelled via AASM (current state: #{contract.status})."
          end
        end
      end

      released_count = released_contract_ids.size
      notify_admin(released_count) if released_count.positive?

      Rails.logger.info "Completed ReleaseUnpaidReservationService: #{released_count} contracts released."
    rescue StandardError => e
      Rails.logger.error "ReleaseUnpaidReservationService failed: #{e.message}"
      raise e
    end

    private

    def notify_admin(released_count)
      notify_admins(
        title: 'Contratos liberados',
        message: "#{released_count} contratos han sido cancelados y liberados debido a falta de pago de reserva.",
        notification_type: 'contracts_released'
      )
    end
  end
end
