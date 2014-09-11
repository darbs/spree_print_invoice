##
# Line items box
#

data = []
@column_widths = { 0 => 75, 1 => 175, 2 => 70, 3 => 60, 4 => 80, 5 => 80 }
@align = { 0 => :left, 1 => :left, 2 => :left, 3 => :right, 4 => :right, 5 => :right}
data << ["SKU", "Item", "Design", "Price", "Quantity", "Total"]

@order.line_items.each do |item|
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
  row << item.single_display_amount.to_s unless @hide_prices
  row << item.quantity
  row << item.display_total.to_s unless @hide_prices

  data << row
end

extra_row_count = 0

unless @hide_prices
  extra_row_count += 1
  data << [""] * 5
  data << [nil, nil, nil, nil, Spree.t(:subtotal), @order.display_item_total.to_s]

  @order.all_adjustments.eligible.each do |adjustment|
    next if adjustment.source_type == "Spree::TaxRate"
    extra_row_count += 1
    data << [nil, nil, nil, nil, adjustment.label, adjustment.display_amount.to_s]
  end

  extra_row_count += 1
  data << [nil, nil, nil, nil, "Tax", @order.display_additional_tax_total.to_s]

  @order.shipments.each do |shipment|
    extra_row_count += 1
    data << [nil, nil, nil, nil, shipment.shipping_method.name, shipment.display_cost.to_s]
  end

  data << [nil, nil, nil, nil, Spree.t(:total), @order.display_total.to_s]
end

move_down(15)

table(data, :width => @column_widths.values.compact.sum, :column_widths => @column_widths) do
  cells.border_width = 0.5


  row(0).borders = [:bottom]
  row(0).font_style = :bold

  cells.column(1).inline_format = true

  last_column = data[0].length - 1
  row(0).columns(0..last_column).borders = [:top, :right, :bottom, :left]
  row(0).columns(0..last_column).border_widths = [0.5, 0, 0.5, 0.5]

  row(0).column(last_column).border_widths = [0.5, 0.5, 0.5, 0.5]

  if extra_row_count > 0
    extra_rows = row((-2-extra_row_count)..-2)
    extra_rows.columns(0..5).borders = []
    extra_rows.column(4).font_style = :bold

    row(-1).columns(0..5).borders = []
    row(-1).column(4).font_style = :bold
  end
end

