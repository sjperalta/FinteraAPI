# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Reports::TotalRevenueReportService do
  describe 'CSV generation with Spanish locale' do
    let(:start_date) { Date.new(2020, 1, 1) }
    let(:end_date) { Date.new(2025, 12, 31) }

    let(:payment_double) do
      double('Payment',
             id: 1,
             description: 'Pago prueba',
             paid_amount: 100.0,
             interest_amount: 5.0,
             due_date: Date.new(2025, 9, 1),
             payment_date: Date.new(2025, 9, 2))
    end

    let(:relation) { double('Payment::Relation') }

    before do
      allow(Payment).to receive(:where).with(status: 'paid', payment_date: start_date..end_date).and_return(relation)
      allow(relation).to receive(:sum).with(:paid_amount).and_return(100.0)
      allow(relation).to receive(:sum).with(:interest_amount).and_return(5.0)
      allow(relation).to receive(:each).and_yield(payment_double)
    end

    it 'generates headers in Spanish and includes a data row and totals' do
      csv = described_class.new(start_date, end_date).call(locale: :es)

      parsed = CSV.parse(csv)

      # First row should be headers
      headers = parsed[0]
      expect(headers).to include('ID Pago')
      expect(headers).to include('Descripción')
      expect(headers).to include('Monto Pagado')
      expect(headers).to include('Monto Interés')
      expect(headers).to include('Fecha de Vencimiento')
      expect(headers).to include('Fecha de Pago')

      # Next non-empty row should contain our payment values
      data_row = parsed.detect { |r| r.any? && r != headers }
      expect(data_row).not_to be_nil
      expect(data_row).to include('1')
      expect(data_row).to include('Pago prueba')
      expect(data_row).to include('100.0')
      expect(data_row).to include('5.0')

      # Summary lines: find the line that contains localized summary label
      summary_index = parsed.index { |r| r.any? && r[0] == I18n.t('reports.total_revenue.summary', locale: :es) }
      expect(summary_index).not_to be_nil

      # Check totals lines exist and are localized
      total_paid_line = parsed[summary_index + 1]
      total_interest_line = parsed[summary_index + 2]
      grand_total_line = parsed[summary_index + 3]

      expect(total_paid_line[0]).to eq(I18n.t('reports.total_revenue.total_paid', locale: :es))
      expect(total_paid_line[1]).to eq('100.0')

      expect(total_interest_line[0]).to eq(I18n.t('reports.total_revenue.total_interest', locale: :es))
      expect(total_interest_line[1]).to eq('5.0')

      expect(grand_total_line[0]).to eq(I18n.t('reports.total_revenue.grand_total', locale: :es))
      expect(grand_total_line[1]).to eq('105.0')
    end

    it 'falls back to default locale when none provided' do
      # set default locale to :en for this example
      original_default = I18n.default_locale
      I18n.default_locale = :en

      csv = described_class.new(start_date, end_date).call
      parsed = CSV.parse(csv)
      headers = parsed[0]
      expect(headers).to include('Payment ID')

      I18n.default_locale = original_default
    end
  end
end
