class MarketplaceApi::V1::OrdersController < MarketplaceApi::V1::ApiController
  before_action :authenticate_user!
  before_action :set_order, only: [:show_all_order_items]
  before_action :set_profile, only: [:purchases, :receipt_data]

  def purchases
    @purchased_orders = @profile.orders.purchased
    @purchases = 
      @purchased_orders.map(&:order_items).flatten
        .uniq { |p| [p.product_id, p.product_type] }
        .map(&:get_item_hash).reverse
        .group_by{|order_item| order_item[:item_type]}
    render status: 200
  end

  def show_all_order_items
    page = params[:page].present? ? params[:page] : 1
    per_page = params[:per_page].present? ? params[:per_page] : 10
    @purchases_hash = []
    @order.order_items.each { |item| @purchases_hash << item.get_item_hash }
    @paginated_sections = @purchases_hash.paginate(page: page, per_page: per_page)
    @pagination = pagination_information(page, per_page, @paginated_sections)
  end

  def receipt_data
    begin
      @purchase = Purchase.find(params[:purchase_id])
      @order = Order.includes(:order_items).find(@purchase.purchase_id)
      @receipt_data = {}
      @receipt_data[:first_name] = @profile.first_name
      @receipt_data[:last_name] = @profile.last_name
      @receipt_order_items_data = []
      @order.order_items.each { |item| @receipt_order_items_data << item.receipt_hash }
      @receipt_data[:order_items] = @receipt_order_items_data
      @receipt_data[:receipt_total] = @order.order_items_total_amount
      pdf_html = ActionController::Base.new.render_to_string(pdf: "file_name",
                                                             template: 'orders/order_receipt_pdf.html.erb',
                                                             layout: 'pdf.html', :locals => {:data => @receipt_data})
      pdf = WickedPdf.new.pdf_from_string(pdf_html)
      rand_string = (0...8).map { (65 + rand(26)).chr }.join
      f = File.new("public/receipt_#{rand_string}.pdf", "wb")
      f.write(pdf_html)
      f.close
      render json: render_success_message({file: "#{Figaro.env.app_base_url}/receipt_#{rand_string}.pdf", data: @receipt_data}, "Receipt data fetched successfully")
    rescue StandardError => e
      render json: {success: false, message: e.message}
    end
  end

  private

  def set_profile
    @profile = current_user.present? ? current_user.profile : nil
  end

  def set_order
    @order = Order.includes(:order_items).find(params[:order_id])
  end

end