# frozen_string_literal: true

require "rails_helper"

RSpec.describe MoneyConvertible do
  describe ".to_cents" do
    it "converts dollars to integer pennies" do
      expect(described_class.to_cents(200.00)).to eq(20_000)
      expect(described_class.to_cents("19.99")).to eq(1_999)
    end

    it "rounds half-up style via BigDecimal to avoid Float drift" do
      expect(described_class.to_cents(0.1 + 0.2)).to eq(30)
    end

    it "rejects nil" do
      expect {
        described_class.to_cents(nil)
      }.to raise_error(ArgumentError, I18n.t("money.errors.amount_blank"))
    end
  end

  describe ".to_dollars" do
    it "converts pennies to BigDecimal dollars" do
      expect(described_class.to_dollars(20_000)).to eq(BigDecimal("200.0"))
    end

    it "rejects nil" do
      expect {
        described_class.to_dollars(nil)
      }.to raise_error(ArgumentError, I18n.t("money.errors.cents_blank"))
    end
  end
end
