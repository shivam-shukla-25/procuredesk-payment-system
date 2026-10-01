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

  describe "payment method enum" do
    it "accepts supported method symbols on payment_method_id" do
      payment = build(:payment, payment_method_id: :check)

      expect(payment).to be_valid
      expect(payment).to be_check
      expect(payment.payment_method).to eq(:check)
    end

    it "accepts string method names" do
      payment = build(:payment, payment_method_id: "charge")

      expect(payment).to be_valid
      expect(payment.payment_method).to eq(:charge)
    end

    it "rejects unknown methods" do
      payment = build(:payment, payment_method_id: :venmo)

      expect(payment).not_to be_valid
      expect(payment.errors[:payment_method_id]).to be_present
    end

    it "exposes the integer mapping used in the database" do
      expect(described_class.payment_method_ids).to eq(
        "cash" => 1,
        "check" => 2,
        "charge" => 3
      )
    end
  end

  describe "#payment_method" do
    it "returns a symbol for a persisted payment" do
      payment = create(:payment, payment_method_id: :cash)

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
      expect(build(:payment, payment_method_id: :cash).valid_payment_method?).to be(true)
    end

    it "is false for unsupported methods" do
      expect(build(:payment).valid_payment_method?(:wire)).to be(false)
    end
  end
end
