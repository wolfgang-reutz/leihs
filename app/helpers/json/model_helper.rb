module Json
  module ModelHelper

    def hash_for_model(model, with = nil)
      h = {
        type: model.class.to_s.underscore,
        id: model.id,
        name: model.name,
        manufacturer: model.manufacturer
      }
      
      if with ||= nil
        [:image_thumb, :description, :is_package, :hand_over_note].each do |k|
          h[k] = model.send(k) if with[k]
        end
        
        if with[:properties]
          with[:properties] = model.properties.as_json # TODO
        end

        if with[:items] and model.respond_to? :items
          Item.unscoped do
            items = model.items 
            items = items.where("items.id IN (#{with[:items][:scoped_ids].to_sql})") unless with[:items][:scoped_ids].nil?
            items = items.search2(with[:items][:query]) if with[:items][:query]
            h[:items] = hash_for items, with[:items]
          end
        end
      
        if with[:categories] and model.respond_to? :categories
          h[:categories] = model.categories.as_json # TODO
        end

        if with[:inventory_pools]
          h[:inventory_pools] = hash_for model.inventory_pools, with[:inventory_pools]
        end
      
        if with[:availability]
          customer_user = with[:availability][:user]
          current_inventory_pool = with[:availability][:inventory_pool]  
      
          if customer_user and current_inventory_pool and (start_date = with[:availability][:start_date]) and (end_date = with[:availability][:end_date])
            # NOTE we display total_rentable_in_stock/total_rentable
            h[:max_available]  = model.availability_in(current_inventory_pool).maximum_available_in_period_for_groups(customer_user.group_ids, start_date, end_date)
            h[:total_rentable] = model.total_borrowable_items_for_user(customer_user, current_inventory_pool)
          elsif current_inventory_pool
            borrowable_items = model.items.scoped_by_inventory_pool_id(current_inventory_pool).borrowable
            # NOTE we display total_rentable_in_stock/total_rentable 
            h[:total_rentable_in_stock] = borrowable_items.in_stock.count
            h[:total_rentable] = borrowable_items.count
          elsif customer_user and current_inventory_pool.nil?
            # NOTE for frontend
            h[:total_borrowable] = model.total_borrowable_items_for_user(customer_user)
            h[:availability_for_user] = model.availability_periods_for_user(customer_user)
          end
          
        end
      end
      
      h
    end

  end
end