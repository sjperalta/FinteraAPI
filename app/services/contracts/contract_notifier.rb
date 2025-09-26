# frozen_string_literal: true

module Contracts
  # Service to handle contract notifications
  class ContractNotifier
    def initialize(contract)
      @contract = contract
    end

    def notify_closed
      create_notification(
        user: @contract.applicant_user,
        title: 'Contrato Cerrado',
        message: "Tu contrato ##{@contract.id} ha sido cerrado. ¡Saldo pagado!",
        notification_type: 'contract_closed'
      )

      notify_admins(
        title: 'Contrato Cerrado',
        message: "Contrato ##{@contract.id} ha sido cerrado automáticamente al saldar la deuda.",
        notification_type: 'contract_closed'
      )
    end

    def notify_approved
      create_notification(
        user: @contract.applicant_user,
        title: 'Contrato Aprobado',
        message: "Tu contrato para #{@contract.lot.name} ha sido aprobado",
        notification_type: 'contract_approved'
      )

      notify_admins(
        title: 'Contrato Aprobado',
        message: "Contrato ##{@contract.id} para #{@contract.lot.name} ha sido aprobado.",
        notification_type: 'contract_approved'
      )
    end

    def notify_rejected
      create_notification(
        user: @contract.applicant_user,
        title: 'Contrato Rechazado',
        message: "Tu contrato para #{@contract.lot.name} ha sido rechazado, detalle: #{@contract.rejection_reason}",
        notification_type: 'contract_rejected'
      )
    end

    def notify_cancelled
      create_notification(
        user: @contract.applicant_user,
        title: 'Contrato Cancelado',
        message: "Tu contrato para #{@contract.lot.name} ha sido cancelado, lote liberado.",
        notification_type: 'contract_cancelled'
      )

      notify_admins(
        title: 'Contrato Cancelado',
        message: "El contrato ##{@contract.id} para #{@contract.lot.name} ha sido cancelado, lote liberado.",
        notification_type: 'contract_cancelled'
      )
    end

    private

    def create_notification(user:, title:, message:, notification_type:)
      Notification.create!(
        user:,
        title:,
        message:,
        notification_type:
      )
    end

    def notify_admins(title:, message:, notification_type:)
      User.admins.each do |admin|
        Notification.create!(
          user: admin,
          title:,
          message:,
          notification_type:
        )
      end
    end
  end
end
