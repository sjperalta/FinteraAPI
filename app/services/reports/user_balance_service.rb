# frozen_string_literal: true

module Reports
  # Service to gather comprehensive data about a user's balance and notify admin
  class UserBalanceService
    def initialize(user_id)
      @user = User.find_by(id: user_id)
      @admin_user = User.find_by(role: 'admin')
      @locale = I18n.default_locale
    end

    def call
      unless @user
        return { success: false,
                 error: I18n.t('reports.user_balance.errors.user_not_found', locale: @locale) }
      end

      notify_user

      {
        success: true,
        user: @user,
        balance: calculate_balance,
        pending_payments: fetch_pending_payments
      }
    rescue StandardError => e
      Rails.logger.error I18n.t('reports.user_balance.errors.user_not_found', message: e.message, locale: @locale)
      { success: false, error: e.message }
    end

    private

    def calculate_balance
      @user.payments.sum(:amount) - @user.payments.sum(:paid_amount)
    end

    def fetch_pending_payments
      @user.payments.pending.overdue
    end

    def notify_user
      return nil if @admin_user.blank?

      Notification.create(
        user: @admin_user,
        title: I18n.t('reports.user_balance.notifications.title', locale: @locale),
        message: I18n.t('reports.user_balance.notifications.message', locale: @locale, user: @user.full_name),
        notification_type: 'create_user_balance'
      )
    end
  end
end
