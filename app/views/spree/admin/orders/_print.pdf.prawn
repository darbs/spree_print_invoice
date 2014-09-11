require 'prawn/layout'
require 'open-uri'
require 'barby'
require 'barby/outputter/prawn_outputter'
require 'barby/barcode/code_39'

##
# Setup
#

@font_face = Spree::PrintInvoice::Config[:print_invoice_font_face]
font @font_face


##
# Logo
#

im = Rails.application.assets.find_asset(Spree::PrintInvoice::Config[:print_invoice_logo_path])
image im , :position => :left, :scale => 0.22


##
# Heading
#


bounding_box([250, 720], :width => 225) do


  fill_color "000000"
  if @order.completed?
    move_down 2
    font @font_face, :size => 12, :style => :bold
    text "Production ##{@order.production_number}", :align => :right
  end

  fill_color "333333"

  move_down 2
  font @font_face,  :size => 10
  text "Order ##{@order.number}", :align => :right

  move_down 2
  font @font_face, :size => 9
  text "Placed on #{I18n.l @order.completed_at.to_date}", :align => :right
end


##
# Indicator
#

bounding_box([515, 700], :width => 40) do
  if @order.invoice_expedited?
    fill_color "d43f3a"
  elsif @order.invoice_priority?
    fill_color "d58512"
  else
    fill_color "398439"
  end

  fill do
    ellipse [9, 0], 20
  end
end


##
# Address
#

fill_color "333333"

bill_address = @order.bill_address
ship_address = @order.ship_address
anonymous = @order.email =~ /@example.net$/


def address_info(address)
  info = %Q{
    #{address.first_name} #{address.last_name}
    #{address.address1}
  }
  info += "#{address.address2}\n" if address.address2.present?
  state = address.state ? address.state.abbr : ""
  info += "#{address.zipcode} #{address.city} #{state}\n"
  info += "#{address.country.name}\n"
  info += "#{address.phone}\n"
  info.strip
end


data = [
  [Spree.t(:billing_address), Spree.t(:shipping_address)],
  [address_info(bill_address) + "\n#{@order.email}", address_info(ship_address) + "\n\nvia #{@order.shipments.first.shipping_method.name}"]
]

move_down 35

table(data, :width => 540) do
  row(0).font_style = :bold

  # Billing address header
  row(0).column(0).borders = [:bottom]
  row(0).column(0).border_widths = [0.5, 0, 0.5, 0.5]

  # Shipping address header
  row(0).column(1).borders = [:bottom]
  row(0).column(1).border_widths = [0.5, 0.5, 0.5, 0]

  # Bill address information
  row(1).column(0).borders = []
  row(1).column(0).border_widths = [0.5, 0, 0.5, 0.5]

  # Ship address information
  row(1).column(1).borders = []
  row(1).column(1).border_widths = [0.5, 0.5, 0.5, 0]

end

horizontal_rule

##
# Shipments
#

@order.shipments.each do |shipment|

    if shipment.expedited?
        fill_color "d43f3a"
    elsif shipment.priority?
        fill_color "d58512"
    else
        fill_color "398439"
    end

    move_down 35
    text "Shipment ##{shipment.number}", :align => :left, :size => 12
    text "#{shipment.shipping_method.name} from #{shipment.stock_location.name} ", :align => :left, :size => 12

    fill_color "000000"

    barcode = Barby::Code39.new(shipment.number)
    barcode.annotate_pdf(pdf, :height => 30, :width => 200, :y => cursor + 2, :x => 335)

    move_down 5

    data = []
    data << ["SKU", "Item", "Design", "Quantity"]

    shipment.manifest.each do |manifestItem|
        item = @order.find_line_item_by_variant(manifestItem.variant)

          if item.design.present?
            row = [ item.variant.product.sku, "#{item.variant.product.name} - " + "<b>with #{item.design.design_type}</b>" ]
          else
            row = [ item.variant.product.sku, item.variant.product.name]
          end
          if item.design.present?
            row << { :image => open(item.design.small), :fit => [70, 70] }
          else
            row << ""
          end
          row << item.quantity
          data << row
    end


    table(data, :width => 535) do
        cells.border_width = 0.5
        cells.border_color = "666666"



     row(0).borders = [:bottom]
     row(0).font_style = :bold

     cells.column(1).inline_format = true

     last_column = data[0].length - 1
     row(0).columns(0..last_column).borders = [:top, :right, :bottom, :left]
     row(0).columns(0..last_column).border_widths = [0.5, 0, 0.5, 0.5]

      row(0).column(last_column).border_widths = [0.5, 0.5, 0.5, 0.5]
    end

end



##
# Instructions
#

move_down 30

text "Special Instructions", :align => :left, :size => 12
    stroke_horizontal_rule

move_down 7
text @order.special_instructions.present? ? @order.special_instructions : "None."

# Footer
render :partial => "footer"

