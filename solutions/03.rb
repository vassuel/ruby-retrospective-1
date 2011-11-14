require 'bigdecimal'
require 'bigdecimal/util'

module Promotion
  def self.for(hash)
    name, options = hash.first

    case name
      when :get_one_free then GetOneFree.new options
      when :package      then Package.new *options.first
      when :threshold    then Threshold.new *options.first
      else NoPromotion.new
    end
  end

  class GetOneFree
    def initialize(nth_item_free)
      @nth_item_free = nth_item_free
    end

    def discount(count, price)
      (count / @nth_item_free) * price
    end

    def name
      "buy #{@nth_item_free - 1}, get 1 free"
    end
  end

  class Package
    def initialize(size, percent)
      @size = size
      @percent = percent
    end

    def discount(count, price)
      multiplier       = @percent / '100'.to_d
      package_discount = price * multiplier * @size
      packages         = count / @size

      package_discount * packages
    end

    def name
      'get %d%% off for every %s' % [@percent, @size]
    end
  end

  class Threshold
    def initialize(threshold, percent)
      @threshold = threshold
      @percent   = percent
    end

    def discount(count, price)
      multiplier            = @percent / '100'.to_d
      item_discount         = price * multiplier
      items_above_threshold = [count - @threshold, 0].max

      items_above_threshold * item_discount
    end

    def name
      suffix = {1 => 'st', 2 => 'nd', 3 => 'rd'}.fetch @threshold, 'th'
      '%2.f%% off of every after the %d%s' % [@percent, @threshold, suffix]
    end
  end

  class NoPromotion
    def discount(count, price)
      0
    end

    def name
      ''
    end
  end
end

module Coupon
  def self.build(name, type)
    case type.keys.first
      when :percent then PercentOff.new name, type[:percent]
      when :amount  then AmountOff.new name, type[:amount]
      else raise "No such coupon: #{type.inspect}"
    end
  end

  class PercentOff
    attr_reader :name

    def initialize(name, percent)
      @name = name
      @percent = percent
    end

    def discount(order_price)
      (@percent / '100'.to_d) * order_price
    end

    def description
      "%d%% off" % @percent
    end
  end

  class AmountOff
    attr_reader :name

    def initialize(name, amount)
      @name   = name
      @amount = amount
    end

    def discount(order_price)
      [order_price, @amount.to_d].min
    end

    def description
      "%-5.2f off" % @amount
    end
  end

  class NoCoupon
    attr_reader :name

    def discount(order_price)
      0
    end
  end
end

class Product
  attr_reader :name, :price, :promotion

  def initialize(name, price, promotion)
    check_name(name)
    check_price(price)

    @name = name
    @price = price
    @promotion = promotion
  end
  
  def check_name(name)
    unless name.length <= 40
      raise "Name should be no more than 40 characters"
    end
  end
  
  def check_price(price)
    unless 0 < price and price < 1000
      raise "Price should be between 0.01 and 999.99" 
    end
  end
end

class Inventory
  def initialize
    @products = []
    @coupons  = []
  end

  def new_cart
    Cart.new self
  end

  def register(name, price, options = {})
    price = price.to_d
    promotion = Promotion.for options

    @products << Product.new(name, price, promotion)
  end

  def register_coupon(name, type)
    @coupons << Coupon.build(name, type)
  end

  def [](name)
    @products.detect { |product| product.name == name } or 
      raise "The product #{name} doesn't exist"
  end

  def coupon(name)
    @coupons.detect { |coupon| coupon.name == name } or Coupon::NoCoupon.new
  end
end

class Cart
  attr_reader :items, :coupon

  def initialize(inventory)
    @inventory  = inventory
    @items      = []
    @coupon     = Coupon::NoCoupon.new
  end

  def add(product_name, count = 1)
    product = @inventory[product_name]
    item    = @items.detect { |item| item.product == product }

    if item
      item.count += count
    else
      @items << Item.new(product, count)
    end
  end

  def use(coupon_name)
    @coupon = @inventory.coupon coupon_name
  end

  def total
    items_price - coupon_discount
  end

  def items_price
    @items.map(&:price).inject(&:+)
  end

  def coupon_discount
    @coupon.discount items_price
  end

  def invoice
    Invoice.new(self).to_s
  end
end

class Item
  attr_reader :product
  attr_accessor :count

  def initialize(product, count)
    @product = product
    @count   = 0

    increase count
  end

  def increase(count)
    raise 'You have to add at least one item' if count <= 0
    raise 'Maximum 99 items of each product' if count + @count > 99
    @count += count
  end

  def product_name
    @product.name
  end

  def price
    price_without_discount - discount
  end

  def price_without_discount
    product.price * count
  end

  def discount
    product.promotion.discount(count, product.price)
  end

  def discount_name
    product.promotion.name
  end

  def discounted?
    not discount.zero?
  end
end

class Invoice
  def initialize(cart)
    @cart = cart
  end

  def to_s
    @output = ""
    print_header
    print_items
    print_total
    @output
  end

  private

  def print_header
    @output << "+------------------------------------------------+----------+\n"
    print 'Name', 'qty', 'price'
    @output << "+------------------------------------------------+----------+\n"
  end

  def print_items
    @cart.items.each do |item|
      print item.product_name, item.count, amount(item.price_without_discount)
      print_discounted_if_existing(item)
    end

    if @cart.coupon_discount.nonzero?
      name = "Coupon #{@cart.coupon.name} - #{@cart.coupon.description}"
      print name, '', amount(-@cart.coupon_discount)
    end
  end
  
  def print_discounted_if_existing(item)
    if item.discounted?
      print "  (#{item.discount_name})", '', amount(-item.discount) 
    end
  end

  def print_total
    @output << "+------------------------------------------------+----------+\n"
    print 'TOTAL', '', amount(@cart.total)
    @output << "+------------------------------------------------+----------+\n"
  end

  def print(*args)
    @output << "| %-40s %5s | %8s |\n" % args
  end

  def amount(decimal)
    "%5.2f" % decimal
  end
end
