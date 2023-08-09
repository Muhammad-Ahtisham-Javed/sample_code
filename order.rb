class Order < ApplicationRecord

  belongs_to :profile
  has_many :order_items, dependent: :destroy

  scope :unpurchased, -> { where(has_purchased: false) }
  scope :purchased, -> { where(has_purchased: true) }

  def order_items_total_amount
    sum = 0
    unpurchased_order_items.each { |item| sum = sum + item.product_details["price"].to_f if item.product_details } if order_items.present?
    sum
    number_with_precision(sum, precision: 2, delimiter: ',')
  end

  def one_time_purchase_items_total_amount
    sum = 0
    items = get_one_time_purchase_items
    items.each { |item| sum = sum + item.product_details["price"].to_f if item.product_details } if items.present?
    sum
    number_with_precision(sum, precision: 2, delimiter: ',')
  end

  def get_order_items_details(profile=nil, custom_order_items=nil)
    items = {}
    order_items_array = custom_order_items.present? ? custom_order_items : unpurchased_order_items
    order_items_array.each do |order_item|
      entity = order_item.product_type.constantize.find_by_id(order_item.product_id)
      event_id =  entity.class.to_s == "Event" ? entity.id : nil
      if entity.present?
        price = order_item.product_details
        entity_hash = entity.order_item_hash
        entity_hash[:partner_pay] = event_id.present? ? check_organization_pay(event_id) : false
        entity_hash[:is_returning] = Order.has_already_purchased(profile, entity)
        entity_hash = entity_hash.merge({price: price})
        entity_hash[:library_plan] = order_item.product_details['plan'] if order_item.product_type == 'Library'
        items[order_item.id] = entity_hash
      end
    end
    items
  end

  def self.has_already_purchased(profile, entity)
    return false if profile.blank? || entity.blank?
    entity_purchase = Purchase.where(purchase_type: entity.class.to_s,
                                     purchase_id: entity.id,
                                     profile_id: profile.id,
                                     returning_user: false).last
    if entity.class.to_s == "AdventistCourses::Course"
      event_ids = Event.joins(groups: :group_profile_mappings).where("events.course_id = ?", entity.id).where("group_profile_mappings.profile_id = ?", profile.id).pluck(:id)
      return false if event_ids.empty?
      if entity_purchase
        (Order.joins(:order_items).where("orders.profile_id = ? AND orders.has_purchased = ?", profile.id , true).where("order_items.product_id IN(?)", event_ids).where("order_items.product_type = ? ", "Event").count > 0 || entity_purchase.present?) && !entity_purchase.refunded
      else
        Order.joins(:order_items).where("orders.profile_id = ? AND orders.has_purchased = ?", profile.id , true).where("order_items.product_id IN(?)", event_ids).where("order_items.product_type = ? ", "Event").count > 0
      end
    else
      if entity_purchase
        (Order.joins(:order_items).where("orders.profile_id = ? AND orders.has_purchased = ?", profile.id , true).where("order_items.product_id = ? AND order_items.product_type = ?", entity.id, entity.class.to_s).count > 0 || entity_purchase.present?) && !entity_purchase.refunded
      else
        Order.joins(:order_items).where("orders.profile_id = ? AND orders.has_purchased = ?", profile.id , true).where("order_items.product_id = ? AND order_items.product_type = ?", entity.id, entity.class.to_s).count > 0
      end
    end
  end

  def current_currency
    order_items.first&.product_details["currency"]
  end

  def get_recurring_items
    unpurchased_order_items.select {|item| item.product_type.singularize.constantize::PRODUCT_TYPE == 'subscription'}
  end

  def get_one_time_purchase_items
    unpurchased_order_items.select {|item| item.product_type.singularize.constantize::PRODUCT_TYPE == 'one_time_purchase'}
  end

  def purchased_one_time_purchase_items!
    get_one_time_purchase_items.each do |order_item|
      order_item.product_details['has_purchased'] = true
      order_item.save
    end
  end

  def unpurchased_order_items
    order_items.select { |order_item| !order_item.product_details['has_purchased'] }
  end

  def purchased_order_items
    order_items.select { |order_item| order_item.product_details['has_purchased'] }
  end

  def purchased_order_items_total_amount
    sum = 0
    items = purchased_order_items
    items.each { |item| sum = sum + item.product_details["price"].to_f if item.product_details } if items.present?
    number_with_precision(sum, precision: 2, delimiter: ',')
  end

  def purchase_items(stripe_token, promo_code_id, discounted_prices)
    statuses = []
    if order_items.present?
      order_items.each do |order_item|
        stripe_service = StripeService.new(
                                            self.profile,
                                            order_item.class.to_s,
                                            order_item.id,
                                            stripe_token,
                                            promo_code_id,
                                            discounted_prices
                                          )
        stripe_service.purchase_one_time_item if order_item.one_time_purchase_item?
        stripe_service.purchase_subscription if order_item.subscription_item?
      end
      self.order_items.reload
      self.order_items.each {|order_item| statuses.push(order_item.product_details["has_purchased"])}
    end
    final_status = statuses.all? { |status| status }
    final_status
  end
end
