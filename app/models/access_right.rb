# == Schema Information
#
# Table name: access_rights
#
#  id                :integer(4)      not null, primary key
#  role_id           :integer(4)
#  user_id           :integer(4)
#  inventory_pool_id :integer(4)
#  created_at        :datetime
#  updated_at        :datetime
#  suspended_until   :date
#  deleted_at        :date
#  access_level      :integer(4)
#
#
class AccessRight < ActiveRecord::Base

  belongs_to :role
  belongs_to :user
  belongs_to :inventory_pool
  has_many :histories, :as => :target, :dependent => :destroy, :order => 'created_at ASC'

  validates_presence_of :user, :role
  validates_uniqueness_of :inventory_pool_id, :scope => :user_id
  validate :validates_inventory_pool

  before_validation_on_create :remove_old
  before_save :adjust_levels
  after_save :update_sphinx_index
  
  named_scope :not_suspended, :conditions => "suspended_until IS NULL OR suspended_until < CURDATE()"
  named_scope :not_admin,     :conditions => "role_id > 1" #TODO: replace hardcoded 1 with Role name (Role.admin)
  
####################################################################

  def to_s
    s = "#{role.name}"
    s += " for #{inventory_pool.name}" if inventory_pool
    #s += " (#{_("Access Level: %d") % access_level.to_i})" if role.name == "manager"
    s += ("(" + _("Access Level: %d") % access_level.to_i + ")") if role.name == "manager"
    s
  end

  def suspended?
    !suspended_until.nil? and suspended_until >= Date.today
  end

  def deactivate
    update_attributes(:deleted_at => DateTime.now)
  end

####################################################################

  private

  def validates_inventory_pool
    if role.name == 'admin'
      errors.add_to_base(_("The admin role cannot be scoped to an inventory pool")) unless inventory_pool.nil?
    else
      errors.add_to_base(_("Inventory Pool is missing")) if inventory_pool.nil?
    end
  end

  def remove_old
    self.inventory_pool = nil if role.name == 'admin'
    unless user.access_rights.empty?
      old_ar = user.access_rights.first(:conditions => { :inventory_pool_id => inventory_pool.id }) if inventory_pool
      user.access_rights.delete(old_ar) if old_ar
    end
  end

  def adjust_levels
    case role.name
      when "admin", "customer"
        self.access_level = nil
      when "manager"
        self.access_level = [access_level.to_i, 1].max
    end
  end

  def update_sphinx_index
    user.touch_for_sphinx
    inventory_pool.touch_for_sphinx if inventory_pool
  end

end
