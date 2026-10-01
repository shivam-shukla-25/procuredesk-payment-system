# Invoice & Payment Refactor

Minimal **Rails 7.2** API app that refactors simplified `Invoice` and `Payment`
models. Scope is intentionally narrow: models, migrations, RSpec, and design
notes — no controllers, views, or auth.

## Stack

| Piece | Choice |
|--------|--------|
| Ruby | 3.4.x (see `.ruby-version`) |
| Rails | 7.2 |
| DB | SQLite |
| Tests | RSpec + FactoryBot + Shoulda Matchers |

## Setup

```bash
bundle install
bin/rails db:setup
bundle exec rspec
```

Optional lint:

```bash
bundle exec rubocop
```

## Usage (public API)

User-facing amounts are **dollars**. Persistence is always **integer pennies**.

```ruby
invoice = Invoice.create_with_dollars!(200.00)  # or create!(total_dollars: 200.00)
invoice.record_payment(100.00, :charge)        # partial payment
invoice.record_payment(100.00, :cash)          # settles the balance

invoice.fully_paid?        # => true
invoice.amount_owed        # => 0.0 (BigDecimal)
invoice.total              # => 20000 (cents)
invoice.total_in_dollars   # => 200.0
```

`total=` is raw cents only. Dollar input goes through `total_dollars` /
`create_with_dollars!` so persisted cents are never accidentally multiplied
again on update.

Domain failures raise `Invoice::PaymentError` (overpay, non-positive amount,
invalid payment method). Message copy lives in `config/locales/en.yml`.

---

## Mistakes in the original code

1. **`fully_paid?` was inverted** — it returned `amount_owed != 0`, so unpaid
   invoices looked “paid.”
2. **`amount_owed` summed the wrong column** — `:amount_paid` does not exist;
   the column is `:amount`.
3. **Cent conversion never assigned** — `translate_invoice_total_to_cents`
   computed `self.invoice_total * 100` and discarded the result.
4. **Integer column truncation** — a create-time callback runs *after*
   ActiveRecord casts `200.00` → `200` on an integer column. Dollar input must
   be converted before that cast (we use a virtual `total_dollars` attribute).
5. **Wrong association** — `Payment` used `has_one :invoice`; payments
   belong to an invoice (`belongs_to`).
6. **Broken method lookup** — `METHODS.value(...)` is not Hash API; forward
   map is `METHODS[symbol]`. Reverse lookup for `#payment_method` needs
   `METHODS.key(id)`, not `METHODS[id]`.
7. **Validation timing** — `payment_method_id` was validated before
   `before_create` set it. Mapping now runs `before_validation`.
8. **`attr_accessible`** — removed in Rails 4; irrelevant on Rails 7.
9. **No graceful failure path** — invalid methods, zero/negative amounts, and
   overpayment were undefined. Callers now get a single domain error type.
10. **Inconsistent units** — comments said “dollars” while internals mixed
    pennies without naming. Public methods return dollars; `*_cents` helpers
    make the unit explicit.

---

## Design decisions

### Money boundary (`MoneyConvertible`)

Currency math is centralized so Invoice and Payment do not each invent
rounding rules. `BigDecimal` avoids classic Float drift (`0.1 + 0.2`).
Blank-input messages are localized under `money.errors.*`.

### `total` instead of `invoice_total`

The column lives on `invoices`, so the `invoice_` prefix adds noise without
clarity. The column stores **cents**.

### Dollars in via `total_dollars` / `create_with_dollars!`

Overriding `total=` to mean “dollars” is convenient for the assignment’s create
example, but unsafe long-term: any later `invoice.update!(total: invoice.total)`
would multiply cents by 100 again.

Instead:

- `total` / `total=` — integer **cents** (DB attribute, no magic)
- `total_dollars` — virtual dollar input, converted in `before_validation`
- `create_with_dollars!(200.00)` — preferred public create API
- `total_in_dollars` — dollar read helper

That keeps the unit boundary explicit and avoids double conversion.

### `Invoice::PaymentError`

Validation errors are fine for attribute-level issues. Overpayment and
“amount must be positive” are **business rules** about recording a payment,
so `record_payment` raises a dedicated error. Controllers (if added later)
can `rescue Invoice::PaymentError` in one place. Copy is in `en.yml`, not
hard-coded strings.

### Payment methods as a Rails enum

The brief’s `payment_method_id` column is kept, but there is no
`payment_methods` table — it is an integer code, not a FK. A Rails `enum`
on that column is the idiomatic expression of that intent: symbol assignment
(`:charge`), query helpers (`charge?`), and inclusion validation via
`validate: true`.

### Partial payments

`has_many :payments` plus `amount_owed_cents` supports multiple payments and
partial settlement without a separate “balance” column (balance is derived,
so it cannot drift from payment rows).

### Concurrent payments (`with_lock` + `lock_version`)

Two clients can both read “$100 owed” and both try to pay $100. Without
serialization that overpays the invoice.

`record_payment` uses `with_lock` so the balance check and payment insert run
in one row-locked transaction. Recording a payment also `touch`es the invoice,
which bumps `lock_version` (optimistic locking). If a stale write still slips
through, we retry a few times and then raise `Invoice::PaymentError` with a
localized concurrent-update message.

### What we deliberately skipped

Service objects, money gems, and a real `PaymentMethod` model would be
reasonable in a larger system. For this scope they would obscure the bugfix
and make review harder. The model layer is enough to prove correctness.

---

## Tests

Specs lock in the original bugs and the intended behavior:

- dollar → cent persistence via `total_dollars` / `create_with_dollars!`
- no double-conversion when reassigning cents through `total=`
- `fully_paid?` / partial payments
- overpay and invalid method errors
- payment method enum mapping and `belongs_to :invoice`
- locked `record_payment` / `lock_version` bump / concurrent-update error

```bash
bundle exec rspec
bin/demo          # optional end-to-end smoke script
```

CI (GitHub Actions) runs Brakeman, RuboCop, and RSpec on `main` / PRs.
