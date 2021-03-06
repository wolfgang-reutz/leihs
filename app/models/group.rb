# == Schema Information
#
# Table name: groups
#
#  id                :integer(4)      not null, primary key
#  name              :string(255)
#  inventory_pool_id :integer(4)
#  delta             :boolean(1)      default(TRUE)
#  created_at        :datetime
#  updated_at        :datetime
#

class Group < ActiveRecord::Base
  include Availability::Group

  belongs_to :inventory_pool
  has_and_belongs_to_many :users
  has_many :partitions
  has_many :models, :through => :partitions, :uniq => true

  validates_presence_of :inventory_pool_id #tmp#2
  validates_presence_of :name

#tmp#2 named_scope :general, :conditions => {:name => 'General', :inventory_pool_id => nil}

  define_index do
    indexes :name, :sortable => true

    has :inventory_pool_id

    set_property :delta => true
  end

##########################################

  def to_s
    name
  end

end

