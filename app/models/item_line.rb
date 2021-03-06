# == Schema Information
#
# Table name: contract_lines
#
#  id            :integer(4)      not null, primary key
#  contract_id   :integer(4)
#  item_id       :integer(4)
#  model_id      :integer(4)
#  quantity      :integer(4)      default(1)
#  start_date    :date
#  end_date      :date
#  returned_date :date
#  created_at    :datetime
#  updated_at    :datetime
#  option_id     :integer(4)
#  type          :string(255)     default("ItemLine"), not null
#

# An ItemLine is a line in a #Contract and as such derived from the
# more general ContractLine. It only contains #Item s but NOT
# #Option s. The latter ones are part of #OrderLine s.
#
# An ItemLine at first only contains a #Model and a desired quantity
# of that #Model. It's only after the #InventoryPool manager has
# picked specific instances of that #Model - which are called "#Items"
# in _leihs_ - that the ItemLines get to contain #Items.
#
# See also the page "Flow" inside the models.graffle document for a
# description of the various steps the lending process goes through.
#
class ItemLine < ContractLine
  
  belongs_to :item
  belongs_to :model

  # TODO validate quantity always 1
  validate :validate_item

# TODO 1301  default_scope :include => :model, :order => "models.name"

  # OPTMIZE 0209** overriding the item getter in order to get a retired item as well if is the case
  def item
    Item.first(:conditions => {:id => item_id}, :retired => :all) if item_id
  end  

  def to_s
    "#{item} - #{end_date.strftime('%d.%m.%Y')}"
  end

# TODO 2602** important: check this method!!!
#  before_save { |record| 
#    unless record.returned_date
#      #TODO 27 Commented for import
#      # But what happens if an inventory manager sees on the next day that he put in the wrong number and wants to correct it?
#      # record.item = nil if record.start_date != Date.today
#      record.start_date = Date.today unless record.item.nil?
#    end
#  }

##################################################

  # custom valid? method
  def complete?
    !self.item.nil? and super
  end

  # TODO 04** merge in complete? 
  def complete_tooltip
    r = super
    r += _("item not assigned. ") unless !self.item.nil?
    return r
  end

##################################################

  def is_late?(current_date = Date.today)
    # an ItemLine can only be late if the Item has been
    # handed out. And an Item can only be handed out, if
    # the contract has been signed. Thus:
    contract.status_const == Contract::SIGNED and super
  end

# TODO 1602**
#  def max_end_date
#    a = model.available_periods_for_document_line(self)
#    d = a.detect {|x| x.start_date >= end_date and x.quantity < 1 }
#    # TODO 1202** make sure we can use end_date of last available period
#    (d ? d.start_date - (1 + model.maintenance_period).days : nil)
#  end

##################################################

  private
    
  # validator
  def validate_item
    if item and contract.status_const == Contract::UNSIGNED
      # model matching
      errors.add_to_base(_("The item doesn't match with the reserved model")) unless item.model == model
  
      # check if available
      errors.add_to_base(_("The item is already handed over or assigned to a different contract line")) if item_already_handed_over_or_assigned?
   
      # inventory_pool matching
      errors.add_to_base(_("The item doesn't belong to the inventory pool related to this contract")) unless item.inventory_pool == contract.inventory_pool 

      # package check 
      errors.add_to_base(_("The item belongs to a package")) if item.parent
    end
  end
  
  def item_already_handed_over_or_assigned?
    item.contract_lines.handed_over_or_assigned_but_not_returned(Date.today).count(:conditions => ["id != ?", id]) > 0
  end
  
end

