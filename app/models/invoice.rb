# frozen_string_literal: true

# Handles simplified invoices (requests for payment).
#
# Public money inputs/outputs use dollars for human comfort; the database
# column +total+ always stores integer pennies. Prefer +create_with_dollars!+
# or +total_dollars=+ for dollar input — do not treat +total=+ as dollars
# (that setter stores raw cents and avoids double-conversion hazards).
class Invoice < ApplicationRecord
  # How many times to retry when optimistic locking detects a concurrent update.
  MAX_PAYMENT_LOCK_RETRIES = 3

  has_many :payments, dependent: :destroy, inverse_of: :invoice

  # Transient dollar input. Converted to +total+ (cents) before validation so
  # ActiveRecord never truncates 200.00 → 200 on the integer column, and so
  # re-assigning persisted cents through +total=+ cannot multiply by 100 again.
  attr_accessor :total_dollars

  before_validation :apply_total_dollars, if: -> { !total_dollars.nil? }

  validates :total, presence: true,
                    numericality: { only_integer: true, greater_than: 0 }

  # Preferred create API for human-facing dollar amounts.
  # Example: Invoice.create_with_dollars!(200.00)
  def self.create_with_dollars!(dollars, **attributes)
    create!(attributes.merge(total_dollars: dollars))
  end

  # Dollar view of the persisted cent total (read-only convenience).
  def total_in_dollars
    return if total.nil?

    MoneyConvertible.to_dollars(total)
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
  #
  # Concurrency: +with_lock+ takes a row lock (transaction + SELECT FOR UPDATE
  # where supported) so the balance check and insert cannot interleave with
  # another payment. +lock_version+ / +touch+ adds optimistic locking so other
  # concurrent invoice updates also conflict instead of silently overwriting.
  #
  # Raises Invoice::PaymentError for domain violations so callers can rescue
  # a single error type instead of probing ActiveRecord validation messages.
  def record_payment(amount_dollars, payment_method)
    cents = MoneyConvertible.to_cents(amount_dollars)

    if cents <= 0
      raise PaymentError, I18n.t("invoice.payments.errors.amount_must_be_positive")
    end

    attempts = 0

    begin
      with_lock do
        if cents > amount_owed_cents
          raise PaymentError, I18n.t(
            "invoice.payments.errors.exceeds_amount_owed",
            amount_owed: amount_owed
          )
        end

        payment = payments.create!(amount: cents, payment_method_id: payment_method)
        # Bumps lock_version so optimistic locking observes this write.
        touch
        payment
      end
    rescue ActiveRecord::StaleObjectError
      attempts += 1
      if attempts >= MAX_PAYMENT_LOCK_RETRIES
        raise PaymentError, I18n.t("invoice.payments.errors.concurrent_update")
      end

      reload
      retry
    rescue ActiveRecord::RecordInvalid => e
      raise PaymentError, e.record.errors.full_messages.to_sentence
    end
  end

  private

  # Writes cents into +total+ from +total_dollars+ once, at the validation
  # boundary, instead of overriding +total=+ permanently.
  def apply_total_dollars
    self.total = MoneyConvertible.to_cents(total_dollars)
  end
end
