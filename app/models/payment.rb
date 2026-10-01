# frozen_string_literal: true

# A single payment applied to an invoice. Amounts are stored in pennies.
# +payment_method_id+ is an enum-like integer code (cash/check/charge),
# not a foreign key — there is no payment_methods table in this schema.
class Payment < ApplicationRecord
  belongs_to :invoice, inverse_of: :payments

  # Rails enum keeps the brief's +payment_method_id+ column while giving us
  # symbol/string assignment, query helpers (cash?), and inclusion validation
  # without a hand-rolled Hash + before_validation callback.
  enum :payment_method_id, { cash: 1, check: 2, charge: 3 }, validate: true

  validates :amount, presence: true,
                     numericality: { only_integer: true, greater_than: 0 }

  # Returns the payment method as a Symbol (:cash, :check, :charge).
  # Enum readers return strings; callers of the original API expected a symbol.
  def payment_method
    payment_method_id&.to_sym
  end

  # Dollar amount for display; storage remains integer cents in +amount+.
  def amount_in_dollars
    MoneyConvertible.to_dollars(amount)
  end

  # True when +method+ (or the current enum value) is a supported method.
  def valid_payment_method?(method = payment_method)
    return false if method.blank?

    self.class.payment_method_ids.key?(method.to_s)
  end
end
