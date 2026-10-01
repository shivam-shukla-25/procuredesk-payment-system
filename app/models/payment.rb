# frozen_string_literal: true

# A single payment applied to an invoice. Amounts are stored in pennies.
# +payment_method_id+ is an enum-like integer code (cash/check/charge),
# not a foreign key — there is no payment_methods table in this schema.
class Payment < ApplicationRecord
  # Explicit integer codes match the assignment data model while giving us
  # a single source of truth for validation and reverse lookup.
  METHODS = { cash: 1, check: 2, charge: 3 }.freeze

  belongs_to :invoice, inverse_of: :payments

  # Transient input from callers (e.g. :charge). Mapped to payment_method_id
  # before validation so presence/inclusion checks see the persisted column.
  attr_accessor :raw_payment_method

  before_validation :assign_payment_method_id, if: -> { raw_payment_method.present? }

  validates :amount, presence: true,
                     numericality: { only_integer: true, greater_than: 0 }
  validates :payment_method_id, presence: true,
                                inclusion: { in: METHODS.values }

  # Returns the payment method as a Symbol (:cash, :check, :charge).
  # The original code indexed METHODS by id (wrong direction) and would
  # always return nil for integer keys.
  def payment_method
    METHODS.key(payment_method_id)
  end

  # Dollar amount for display; storage remains integer cents in +amount+.
  def amount_in_dollars
    MoneyConvertible.to_dollars(amount)
  end

  # True when the raw method symbol is one we accept.
  # Kept for clarity/testing; validation also enforces this via METHODS.
  def valid_payment_method?
    METHODS.key?(normalized_raw_payment_method)
  end

  private

  # Maps raw_payment_method (:charge / "charge") onto payment_method_id.
  # Uses Hash#[] (symbol → id). The original called Hash#value, which is not
  # a Hash API (#key / values reverse-lookup by value).
  def assign_payment_method_id
    method_key = normalized_raw_payment_method

    unless METHODS.key?(method_key)
      errors.add(
        :raw_payment_method,
        I18n.t("activerecord.errors.models.payment.attributes.raw_payment_method.unsupported")
      )
      return
    end

    self.payment_method_id = METHODS[method_key]
  end

  def normalized_raw_payment_method
    raw_payment_method.to_s.downcase.to_sym
  end
end
