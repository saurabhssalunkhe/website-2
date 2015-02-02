require "Mollie/API/Client"

class Order < ActiveRecord::Base
  has_paper_trail

  has_many :students

  validate :validate_cart

  validates_presence_of :identifier

  validates_presence_of :billing_name, :billing_email, :billing_address,
                        :billing_postal, :billing_city, :billing_country,
                        :billing_phone, :cart

  validate :validate_students_amount

  validates :terms_and_conditions, inclusion: { in: [true], message: 'must be accepted.' }

  accepts_nested_attributes_for :students

  before_validation :create_identifier

  def to_param
    self.identifier
  end

  def current_step
    @current_step || steps.first
  end

  def current_step=(step)
    raise ArgumentError.new("Step #{step} does not exist!") unless steps.include?(step) || step.nil?
    @current_step = step
  end

  def steps
    steps = (0...cart_sum_tickets).map{ |i| "students-#{i}" }
    steps.unshift "details"
    steps.unshift "tickets"
    steps.push  "confirmation"
  end

  def next_step
    step_index = [steps.index(current_step)+1, (steps.size-1)].min
    self.current_step = steps[step_index]
  end

  def previous_step
    step_index = [steps.index(current_step)-1, 0].max
    self.current_step = steps[step_index]
  end

  def first_step?
    current_step == steps.first
  end

  def last_step?
    current_step == steps.last
  end

  def all_valid?
    steps.all? do |step|
      self.current_step = step
      valid?
    end
  end

  def confirmed?
    persisted? && confirmed_at.present?
  end

  def ticket_types
    ticket_prices.keys
  end

  def ticket_prices
    {
      early_bird: 1499,
      normal: 1799,
      supporter: 1999
    }
  end

  def cart
    (super || {}).with_indifferent_access
  end

  def cart_sum_total
    ticket_prices.map do |type, price|
      cart[type].to_i * price
    end.inject(&:+)
  end

  def cart_sum_tickets
    ticket_prices.keys.map do |type|
      cart[type].to_i
    end.inject(&:+)
  end

  def validate_cart
    return if cart_valid?
    errors.add(:cart, "Please select 1 or more tickets.")
  end

  def validate_students_amount
    return if students.size == cart_sum_tickets
    errors.add(:students, "You need to provide details for all #{cart_sum_tickets} students.")
  end

  def cart_valid?
    cart_has_valid_ticket_types? &&
      cart_sum_total >= ticket_prices.values.min &&
        cart_has_positive_amounts_for_tickets?
  end

  def cart_has_valid_ticket_types?
    ((cart.keys.map(&:to_sym) - ticket_types) + (ticket_types - cart.keys.map(&:to_sym))).empty?
  end

  def cart_has_positive_amounts_for_tickets?
    return true if cart.values.select{|v| v.to_i >= 0 }.size == cart.values.size &&
      cart_sum_tickets > 0
    errors.add(:cart, "You can only order amounts of 1 or more tickets.")
    return false
  end

  def create_identifier
    return if persisted? # Don't overwrite existing identifiers
    self.identifier = SecureRandom.uuid
    create_identifier if Order.where(identifier: self.identifier).count > 0
  end

  def create_payment(options = {})
    _payment = mollie.payments.create options.merge(
      amount: (cart_sum_total.to_f),
      description: "Development Bootcamp tuition fee",
      metadata: { identifier: self.identifier})
    update(mollie_payment_id: _payment.id)
    _payment
  end

  def payment
    return unless self.mollie_payment_id.present?
    mollie.payments.get self.mollie_payment_id rescue nil
  end

  def paid?
    manually_paid? || paid_by_creditcard? || (payment && payment.paid?)
  end

  def mollie
    @mollie || setup_mollie
  end

  def setup_mollie
    @mollie = Mollie::API::Client.new
    @mollie.setApiKey ENV['DB_MOLLY_KEY'] || ""
    @mollie
  end
end