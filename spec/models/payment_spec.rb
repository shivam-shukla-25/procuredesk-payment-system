# frozen_string_literal: true

require "rails_helper"

RSpec.describe Payment, type: :model do
  describe "associations" do
    it { is_expected.to belong_to(:invoice) }
  end

  describe "validations" do
    subject { build(:payment) }

    it { is_expected.to validate_presence_of(:amount) }
    it { is_expected.to validate_numericality_of(:amount).only_integer.is_greater_than(0) }
  end

  describe "payment method mapping" do
    it "maps raw_payment_method symbols onto payment_method_id before validation" do
      payment = build(:payment, raw_payment_method: :check)

      expect(payment).to be_valid
      expect(payment.payment_method_id).to eq(2)
      expect(payment.payment_method).to eq(:check)
    end

    it "accepts string method names" do
      payment = build(:payment, raw_payment_method: "CHARGE")

      expect(payment).to be_valid
      expect(payment.payment_method).to eq(:charge)
    end

    it "rejects unknown methods" do
      payment = build(:payment, raw_payment_method: :venmo)

      expect(payment).not_to be_valid
      expect(payment.errors[:raw_payment_method]).to be_present
    end
  end

  describe "#payment_method" do
    it "returns a symbol for a persisted payment_method_id" do
      payment = create(:payment, raw_payment_method: :cash)

      expect(payment.reload.payment_method).to eq(:cash)
    end
  end

  describe "#amount_in_dollars" do
    it "exposes the stored cents as dollars" do
      payment = build(:payment, amount: 1_999)

      expect(payment.amount_in_dollars).to eq(BigDecimal("19.99"))
    end
  end

  describe "#valid_payment_method?" do
    it "is true for supported methods" do
      expect(build(:payment, raw_payment_method: :cash).valid_payment_method?).to be(true)
    end

    it "is false for unsupported methods" do
      expect(build(:payment, raw_payment_method: :wire).valid_payment_method?).to be(false)
    end
  end
end
