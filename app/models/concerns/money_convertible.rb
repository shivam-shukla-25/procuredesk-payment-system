# frozen_string_literal: true

# Centralizes dollar ↔ cent conversion so Invoice and Payment never
# reimplement rounding rules. Using BigDecimal avoids Float binary drift
# (e.g. 19.99 * 100 becoming 1998.999…).
module MoneyConvertible
  module_function

  # Converts a human-facing dollar amount into integer pennies for persistence.
  def to_cents(dollars)
    raise ArgumentError, I18n.t("money.errors.amount_blank") if dollars.nil?

    (BigDecimal(dollars.to_s) * 100).round.to_i
  end

  # Converts persisted pennies into a BigDecimal dollar amount for display/API use.
  def to_dollars(cents)
    raise ArgumentError, I18n.t("money.errors.cents_blank") if cents.nil?

    BigDecimal(cents.to_i) / 100
  end
end
