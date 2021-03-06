# == Schema Information
#
# Table name: models
#
#  id                   :integer(4)      not null, primary key
#  name                 :string(255)     not null
#  manufacturer         :string(255)
#  description          :string(255)
#  internal_description :string(255)
#  info_url             :string(255)
#  rental_price         :decimal(8, 2)
#  maintenance_period   :integer(4)      default(0)
#  is_package           :boolean(1)      default(FALSE)
#  created_at           :datetime
#  updated_at           :datetime
#  technical_detail     :string(255)
#  delta                :boolean(1)      default(TRUE)
#

# A Model is a type of a thing which is available inside
# an #InventoryPool for borrowing. If a customer wants to
# borrow a thing, he opens an #Order and chooses the
# appropriate Model. The #InventoryPool manager then hands
# him over an instance - an #Item - of that Model, in case
# one is still available for borrowing.
#
# The description of the #Item class contains an example.
#
#
class Model < ActiveRecord::Base
  include Availability::Model

  def before_destroy
    errors.add_to_base "Model cannot be destroyed because related items are still present." if items.count(:retired => :all) > 0
    if is_package? and order_lines.empty? and contract_lines.empty?
      items.destroy_all
    else
      return false
    end

# TODO allow to delete a model that doesn't have items
#    if is_package? and order_lines.empty? and contract_lines.empty?
#      items.destroy_all
#    elsif items.count(:retired => :all) > 0
#      errors.add_to_base "Model cannot be destroyed because related items are still present."
#      return false
#    end
  end

  has_many :items
  has_many :unretired_items, :class_name => "Item", :conditions => {:retired => nil}
  has_many :borrowable_items, :class_name => "Item", :conditions => {:retired => nil, :is_borrowable => true, :parent_id => nil}
  has_many :unpackaged_items, :class_name => "Item", :conditions => {:parent_id => nil}
  
  has_many :locations, :through => :items, :uniq => true  # OPTIMIZE N+1 select problem, :include => :inventory_pools
  has_many :inventory_pools, :through => :items, :uniq => true

  has_many :partitions, :dependent => :delete_all do
    def in(inventory_pool)
      @inventory_pool = inventory_pool
      @model = proxy_owner

      class << self
        def set(new_partitions)
          clear
          new_partitions.delete(Group::GENERAL_GROUP_ID)
          unless new_partitions.blank?
            valid_group_ids = @inventory_pool.group_ids
            new_partitions.each_pair do |group_id, quantity|
              group_id = group_id.to_i
              quantity = quantity.to_i
              create(:group_id => group_id, :quantity => quantity) if valid_group_ids.include?(group_id) and quantity > 0
            end
          end
          # if there's no more items of a model in a group accessible to the customer,
          # then he shouldn't be able to see the model in the frontend. Therefore we need to reindex
          @model.touch_for_sphinx # OPTIMIZE: only reindex frontend data
          # TODO: we're breaking the separation of concerns principle here:
          #       availablity concerns should be exclusively dealt with inside
          #       models/availabilit/* 
          @model.delete_availability_changes_in(@inventory_pool)
        end

        # returns a hash {nil => 10, 41 => 3, 42 => 6, ...}
        def current_partition
          r = {Group::GENERAL_GROUP_ID => by_group(Group::GENERAL_GROUP_ID)} # this are available for general group
          all.each {|p| r[p.group_id] = p.quantity } # these are the partitions defined by the inventory manager
          r
        end
        
        def by_group(group)
          if group.nil?
            #tmp#1402 @inventory_pool.items.borrowable.scoped_by_model_id(@model).count - sum(:quantity)
            
            quantity = @inventory_pool.items.borrowable.scoped_by_model_id(@model).count - sum(:quantity, :conditions => "group_id IS NOT NULL")
            p = first(:conditions => {:group_id => Group::GENERAL_GROUP_ID})
            if quantity > 0
              if p
                p.update_attributes(:quantity => quantity)
              else
                create(:group_id => Group::GENERAL_GROUP_ID, :quantity => quantity)
              end
            elsif p
              p.destroy
            end
            quantity # TODO return p ??
          else
            scoped_by_group_id(group).first
          end
        end
        
        def by_groups(groups)
          scoped( { :conditions => {:group_id => groups} } )
        end
      end
      
      scoped( { :conditions => {:inventory_pool_id => inventory_pool} } )
    end
  end
  
  has_many :order_lines
  has_many :contract_lines
  has_many :properties, :dependent => :destroy
  has_many :accessories, :dependent => :destroy
  has_many :images, :dependent => :destroy
  has_many :attachments, :dependent => :destroy

  # ModelGroups
  has_many :model_links, :dependent => :destroy
  has_many :model_groups, :through => :model_links, :uniq => true
  has_many :categories, :through => :model_links, :source => :model_group, :conditions => {:type => 'Category'}
  has_many :templates, :through => :model_links, :source => :model_group, :conditions => {:type => 'Template'}
  
  # Packages
  has_many :package_items, :through => :items, :source => :children
  def package_models
    # NOTE assuming all roots have the same children structure
    items.each do |item|
      return item.children.collect(&:model) unless item.children.empty?
    end if is_package?
    return []
  end

########
  # says which other Model one Model works with
  has_and_belongs_to_many :compatibles,
                          :class_name => "Model",
                          :join_table => "models_compatibles",
                          :foreign_key => "model_id",
                          :association_foreign_key => "compatible_id",
                     #TODO :insert_sql => "INSERT INTO models_compatibles (model_id, compatible_id)
                     #                 VALUES (#{id}, #{record.id}), (#{record.id}, #{id})" 
                          :after_add => [:add_bidirectional_compatibility, :update_sphinx_index_compatibility],
                          :after_remove => [:remove_bidirectional_compatibility, :update_sphinx_index_compatibility]
  def add_bidirectional_compatibility(compatible)
    compatible.compatibles << self unless compatible.compatibles.include?(self)
  end
  
  def remove_bidirectional_compatibility(compatible)
    compatible.compatibles.delete(self) if compatible.compatibles.include?(self)
  end
  
  def update_sphinx_index_compatibility(compatible)
    self.touch_for_sphinx
    compatible.touch_for_sphinx
  end

#############################################  

  validates_presence_of :name
  validates_uniqueness_of :name

#############################################  

  # OPTIMIZE Mysql::Error: Not unique table/alias: 'items'
  named_scope :active, :select => "DISTINCT models.*",
                       :joins => :items,
                       :conditions => "items.retired IS NULL"

  named_scope :without_items, :select => "models.*",
                              :joins => "LEFT JOIN items ON items.model_id = models.id",
                              :conditions => ['items.model_id IS NULL']
                              
  named_scope :packages, :conditions => { :is_package => true }
  
  named_scope :with_properties, :select => "DISTINCT models.*",
                                :joins => "LEFT JOIN properties ON properties.model_id = models.id",
                                :conditions => "properties.model_id IS NOT NULL"

  named_scope :by_inventory_pool, lambda { |inventory_pool| { :select => "DISTINCT models.*",
                                                              :joins => :items,
                                                              :conditions => ["items.inventory_pool_id = ?", inventory_pool] } }

  named_scope :by_categories, lambda { |categories| { :joins => "INNER JOIN model_links AS ml", # OPTIMIZE no ON ??
                                                      :conditions => ["ml.model_group_id IN (?)", categories] } }

#############################################

  after_save :update_sphinx_index

#############################################

  define_index do
    indexes :name, :sortable => true
    indexes :manufacturer, :sortable => true
    indexes categories(:name), :as => :category_names
    indexes properties(:value), :as => :properties_values
    indexes items(:inventory_code), :as => :items_inventory_codes
    
    has :is_package
    has compatibles(:id), :as => :compatible_id
    has categories(:id), :as => :category_id
#    has items(:inventory_pool_id), :as => :inventory_pool_id
#    has items(:owner_id), :as => :owner_id
    has unretired_items(:inventory_pool_id), :as => :unretired_inventory_pool_id
    has unretired_items(:owner_id), :as => :unretired_owner_id

    # item has at least one NULL parent_id and thus it has items that were not packaged
    # we collect all the inventory pools for which this is the case
    has "(SELECT GROUP_CONCAT(DISTINCT i.inventory_pool_id) FROM items i WHERE i.model_id = models.id AND i.parent_id IS NULL)",
        :as => :inventory_pools_with_unpackaged_items, :type => :multi
#    has unpackaged_items(:inventory_pool_id), :as => :unpackaged_inventory_pool_id
    
    # set_property :order => :name
    set_property :delta => true
  end

  define_index "frontend_model" do
    # where "is_package = 1"
    
    indexes :name, :sortable => true
    indexes :manufacturer, :sortable => true
    indexes properties(:value), :as => :properties_values
    
    has :is_package
    has categories(:id), :as => :category_id
    
    set_property :delta => true
  end

#old#  sphinx_scope(:sphinx_active) { {:without => {:active_item_id => 0}} }
  sphinx_scope(:sphinx_packages) { {:with => {:is_package => true}} }
  sphinx_scope(:sphinx_with_unpackaged_items) { |inventory_pool_id|
                                                {:with => {:inventory_pools_with_unpackaged_items => inventory_pool_id.to_s}} }

  def touch_for_sphinx
    @block_delta_indexing = true
    touch
  end

  private
  def update_sphinx_index
    return if @block_delta_indexing
    Item.suspended_delta do # FIXME doesn't work!!!
      items.each {|x| x.touch_for_sphinx }
    end
  end
  public

#############################################  

  def to_s
    "#{name}"
  end

  # compares two objects in order to sort them
  def <=>(other)
    self.name <=> other.name
  end

  # TODO 06** define main image
  def image_thumb
    ( images.empty? ? nil : images.first.public_filename(:thumb) )
  end

  def lines
    order_lines.submitted + contract_lines
  end
  
  def needs_permission
    items.each do |item|
      return true if item.needs_permission
    end
    return false
  end

#############################################  

  def add_to_document(document, user_id, quantity = nil, start_date = nil, end_date = nil, inventory_pool = nil)
    document.add_line(quantity, self, user_id, start_date, end_date, inventory_pool)
  end  

  def running_reservations(inventory_pool, current_time = Date.today)
    return   self.contract_lines.by_inventory_pool(inventory_pool).handed_over_or_assigned_but_not_returned(current_time) \
           + self.order_lines.scoped_by_inventory_pool_id(inventory_pool).submitted.running(current_time)    
  end
                                                                                                      
end

