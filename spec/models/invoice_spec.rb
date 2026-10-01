# frozen_string_literal: true

require "rails_helper"

RSpec.describe Invoice, type: :model do
  describe "associations" do
    it { is_expected.to have_many(:payments).dependent(:destroy) }
  end

  describe "validations" do
    it "requires a positive total" do
      invoice = described_class.new(total: 0)
      expect(invoice).not_to be_valid
      expect(invoice.errors[:total]).to be_present
    end
  end

  describe "dollar → cent persistence" do
    it "stores total in pennies when created with dollars" do
      # Matches the assignment's primary example API (dollars in, cents stored).
      invoice = described_class.create!(total: 200.00)

      expect(invoice.reload.total).to eq(20_000)
    end

    it "treats bare integers as dollars as well (200 → 20000 cents)" do
      invoice = described_class.create!(total: 200)

      expect(invoice.total).to eq(20_000)
    end
  end

  describe "#fully_paid?" do
    let(:invoice) { create(:invoice, total: 200.00) }

    it "is false when nothing has been paid" do
      expect(invoice).not_to be_fully_paid
    end

    it "is false when only partially paid" do
      invoice.record_payment(100.00, :charge)
      expect(invoice).not_to be_fully_paid
    end

    it "is true when payments cover the total" do
      invoice.record_payment(100.00, :charge)
      invoice.record_payment(100.00, :cash)
      expect(invoice).to be_fully_paid
    end
  end

  describe "#amount_owed" do
    let(:invoice) { create(:invoice, total: 200.00) }

    it "returns the full total in dollars with no payments" do
      expect(invoice.amount_owed).to eq(BigDecimal("200.0"))
    end

    it "subtracts recorded payments (partial payment support)" do
      invoice.record_payment(50.00, :check)
      expect(invoice.amount_owed).to eq(BigDecimal("150.0"))
    end
  end

  describe "#record_payment" do
    let(:invoice) { create(:invoice, total: 200.00) }

    it "records a payment in pennies with the given method" do
      payment = invoice.record_payment(100.00, :charge)

      expect(payment.amount).to eq(10_000)
      expect(payment.payment_method).to eq(:charge)
      expect(payment.payment_method_id).to eq("charge")
      expect(payment.read_attribute_before_type_cast(:payment_method_id)).to eq(3)
    end

    it "allows multiple payments toward one invoice" do
      invoice.record_payment(75.00, :cash)
      invoice.record_payment(25.00, :check)

      expect(invoice.payments.count).to eq(2)
      expect(invoice.amount_owed).to eq(BigDecimal("100.0"))
    end

    it "raises when the amount is zero or negative" do
      expect {
        invoice.record_payment(0, :cash)
      }.to raise_error(
        Invoice::PaymentError,
        I18n.t("invoice.payments.errors.amount_must_be_positive")
      )
    end

    it "raises when the payment would overpay the invoice" do
      invoice.record_payment(150.00, :cash)

      expect {
        invoice.record_payment(100.00, :charge)
      }.to raise_error(
        Invoice::PaymentError,
        I18n.t("invoice.payments.errors.exceeds_amount_owed", amount_owed: invoice.amount_owed)
      )
    end

    it "raises a domain error for an unsupported payment method" do
      expect {
        invoice.record_payment(10.00, :bitcoin)
      }.to raise_error(Invoice::PaymentError)
    end
  end
end
