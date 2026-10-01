# frozen_string_literal: true

# Handles simplified invoices (requests for payment).
#
# Public money inputs/outputs use dollars for human comfort; the database
# column +total+ always stores integer pennies.
class Invoice < ApplicationRecord
  has_many :payments, dependent: :destroy, inverse_of: :invoice

  validates :total, presence: true,
                    numericality: { only_integer: true, greater_than: 0 }

  # Accepts a dollar amount (per the assignment create example) and persists
  # it as pennies. Conversion happens in the writer — before ActiveRecord's
  # integer type caster truncates 200.00 → 200 — and we actually assign the
  # result (the original callback computed `* 100` but discarded it).
  #
  # Both 200 and 200.00 are treated as dollars ($200.00 → 20_000 cents).
  def total=(value)
    return super(nil) if value.nil?

    super(MoneyConvertible.to_cents(value))
  end

  # Returns true when the invoice balance is fully settled.
  # The original implementation inverted this check (`amount_owed != 0`).
  def fully_paid?
    amount_owed_cents.zero?
  end

  # Remaining balance in dollars (BigDecimal) for user-facing display.
  def amount_owed
    MoneyConvertible.to_dollars(amount_owed_cents)
  end

  # Remaining balance in pennies for internal arithmetic and validations.
  # Named explicitly so callers never guess the unit. Uses +amount+ (the
  # real column) — the original summed a non-existent :amount_paid.
  def amount_owed_cents
    total - payments.sum(:amount)
  end

  # Amount already collected, in dollars.
  def amount_paid
    MoneyConvertible.to_dollars(payments.sum(:amount))
  end

  # Records a payment in dollars against this invoice.
  # Raises Invoice::PaymentError for domain violations so callers can rescue
  # a single error type instead of probing ActiveRecord validation messages.
  def record_payment(amount_dollars, payment_method)
    cents = MoneyConvertible.to_cents(amount_dollars)

    if cents <= 0
      raise PaymentError, I18n.t("invoice.payments.errors.amount_must_be_positive")
    end

    if cents > amount_owed_cents
      raise PaymentError, I18n.t(
        "invoice.payments.errors.exceeds_amount_owed",
        amount_owed: amount_owed
      )
    end

    payments.create!(amount: cents, raw_payment_method: payment_method)
  rescue ActiveRecord::RecordInvalid => e
    raise PaymentError, e.record.errors.full_messages.to_sentence
  end
end
