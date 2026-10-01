# frozen_string_literal: true

FactoryBot.define do
  factory :invoice do
    total { 200.00 }
  end

  factory :payment do
    invoice
    amount { 10_000 } # $100.00 in cents — Payment stores pennies directly
    raw_payment_method { :cash }
  end
end
