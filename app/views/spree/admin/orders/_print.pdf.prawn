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
# Line items box
#

data = []

@column_widths = { 0 => 210, 1 => 80, 2 => 75, 3 => 85, 4 => 95 }

@align = { 0 => :left, 1 => :left, 2 => :left, 3 => :right, 4 => :right}
data << ["Item", "Design", "Price", "Quantity", "Total"]

@order.line_items.each do |item|

  row = []

  if item.design.present?
    row << "<i>#{item.variant.sku}</i> " + "<br> <b>#{item.variant.product.name}</b> <br>+#{item.design.design_type}"
  else
    row << "<i>#{item.variant.sku}</i> " + "<br> <b>#{item.variant.product.name}</b>"
  end

  if item.design.present?
    row << { :image => open(item.design.small), :fit => [70, 70] }
  else
    row << ""
  end

  row << item.single_display_amount.to_s unless @hide_prices
  row << item.quantity
  row << item.display_total.to_s unless @hide_prices

  data << row
end

extra_row_count = 0

unless @hide_prices
  extra_row_count += 1
  data << [""] * 5
  data << [nil, nil, nil,  Spree.t(:subtotal), @order.display_item_total.to_s]

  @order.all_adjustments.eligible.each do |adjustment|
    next if adjustment.source_type == "Spree::TaxRate"
    extra_row_count += 1
    data << [nil, nil, nil, adjustment.label, adjustment.display_amount.to_s]
  end

  extra_row_count += 1
  data << [nil, nil, nil,  "Tax", @order.display_additional_tax_total.to_s]

  @order.shipments.each do |shipment|
    extra_row_count += 1
    data << [nil, nil, nil, shipment.shipping_method.name, shipment.display_cost.to_s]
  end

  extra_row_count += 1
  data << [nil, nil, nil, Spree.t(:total), @order.display_total.to_s]
end

move_down(15)

table(data, :width => @column_widths.values.compact.sum, :column_widths => @column_widths) do
  cells.border_width = 0.5

  row(0).borders = [:bottom]
  row(0).font_style = :bold

  cells.column(0).inline_format = true

  last_column = data[0].length - 1
  row(0).columns(0..last_column).borders = [:top, :right, :bottom, :left]
  row(0).columns(0..last_column).border_widths = [0.5, 0, 0.5, 0.5]

  row(0).column(last_column).border_widths = [0.5, 0.5, 0.5, 0.5]

  if extra_row_count > 0
    extra_rows = row((-1-extra_row_count)..-1)
    extra_rows.columns(0..5).borders = []
    extra_rows.column(4).font_style = :bold
    extra_rows.columns(0..5).padding = [1, 5]
  end
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
    data << ["Quantity", "Item", "Design"]

    shipment.manifest.each do |item|

          row = [item.quantity]

          if item.line_item.design.present?
            row << "<i>#{item.variant.sku}</i> " + "<br> <b>#{item.variant.product.name}</b> <br>+#{item.line_item.design.design_type}"
          else
            row << "<i>#{item.variant.sku}</i> " + "<br> <b>#{item.variant.product.name}</b>"
          end

          if item.line_item.design.present?
            row << { :image => open(item.line_item.design.small), :fit => [70, 70] }
          else
            row << ""
          end

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

move_down 25

text "Special Instructions", :align => :left, :size => 12
    stroke_horizontal_rule

move_down 7
text @order.special_instructions.present? ? @order.special_instructions : "None."


##
# Gift message
#

move_down 15

text "Gift Message", :align => :left, :size => 12
    stroke_horizontal_rule

move_down 7
text @order.gift_message.present? ? @order.gift_message : "None."

# Footer
render :partial => "footer"

