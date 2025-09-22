# frozen_string_literal: true

class Revenue < ApplicationRecord
  # Constants
  PAYMENT_TYPES = %w[reservation down_payment installment].freeze

  # Validations
  validates :payment_type, presence: true, inclusion: { in: PAYMENT_TYPES }
  validates :year, presence: true, numericality: { greater_than_or_equal_to: 2000, only_integer: true }
  validates :month, presence: true,
                    numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 12, only_integer: true }
  validates :amount, numericality: { greater_than_or_equal_to: 0 }

  # Scopes
  scope :for_year, ->(year) { where(year:) }
  scope :for_month, ->(month) { where(month:) }
  scope :for_payment_type, ->(type) { where(payment_type: type) }

  # Methods
  def self.total_revenue_for_year(year)
    where(year:).group(:payment_type).sum(:amount)
  end

  def self.monthly_revenue_for_year_and_type(year, type)
    where(year:, payment_type: type).order(:month).pluck(:amount)
  end

  # Helper for formatted amount
  def formatted_amount
    "$#{'%.2f' % amount}"
  end
end
