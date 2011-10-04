# Document is an abstract superclass for #Order and #Contract.
# A Document consists of #DocumentLine s.
#
class Document < ActiveRecord::Base
  self.abstract_class = true
  
  has_many :histories, :as => :target, :dependent => :destroy, :order => 'created_at ASC'
  has_many :actions, :as => :target, :class_name => "History", :order => 'created_at ASC', :conditions => "type_const = #{History::ACTION}"

  # compares two objects in order to sort them
  def <=>(other)
    self.created_at <=> other.created_at
  end

  def to_s
    "#{id}"
  end

  def lines( reload = false )
    # abstract method implemented in #Order.lines or #Contract.lines
    raise "Abstract method called"
  end

  def quantity
    lines.collect(&:quantity).sum
  end

################################################################

  def time_window_min
    lines.minimum(:start_date) || Date.today
  end
  
  def time_window_max
    lines.maximum(:end_date) || Date.today
  end
  
  def max_single_range
    lines.select("DATEDIFF(end_date, start_date) + 1 as time_window").
          reorder("time_window DESC").
          limit(1).
          first.try(:time_window).to_i
  end
  
  def next_open_date(x)
    x = Date.today if x.nil?
    if inventory_pool
      inventory_pool.next_open_date(x)
    else
      x
    end
  end
  
################################################################

  def add_line(quantity, model, user_id, start_date = nil, end_date = nil, inventory_pool = nil)
      end_date = start_date if end_date and start_date and end_date < start_date

      attr = { :quantity => quantity || 1,
               :model => model,
               :start_date => start_date || time_window_min,
               :end_date => end_date || next_open_date(time_window_max) }

      line = if self.is_a?(Order)
        order_lines.create(attr) do |l|
          l.inventory_pool = inventory_pool if inventory_pool
        end
      else
        item_lines.create(attr)
      end

      log_change(_("Added") + " #{quantity} #{model.name} #{start_date} #{end_date}", user_id) unless line.new_record?             
  end

  def swap_line(line_id, model_id, user_id)
    line = lines.find(line_id.to_i)
    if (line.model.id != model_id.to_i)
      model = Model.find(model_id.to_i)
      change = _("Swapped %{from} for %{to}") % { :from => line.model.name, :to => model.name}
      line.item = nil if line.is_a?(ItemLine)
      line.model = model
      log_change(change, user_id)
      line.save
    end
  end

  def update_time_line(line_id, start_date, end_date, user_id)
    line = lines.find(line_id)
    start_date ||= line.start_date
    end_date ||= line.end_date
    original_start_date = line.start_date
    original_end_date = line.end_date
    line.start_date = start_date
    line.end_date = [start_date, end_date].max
    if line.save
      change = _("Changed dates for %{model} from %{from} to %{to}") % { :model => line.model.name, :from => "#{original_start_date} - #{original_end_date}", :to => "#{line.start_date} - #{line.end_date}" }
      log_change(change, user_id)
    else
      line.errors.each_full do |msg|
        errors.add(:base, msg)
      end
    end
  end 
  
  def remove_line(line_or_id, user_id)
    line = line_or_id.is_a?(DocumentLine) ? line_or_id : lines.find(line_or_id.to_i)
    change = _("Removed %{q} %{m}") % { :q => line.quantity, :m => line.model.name }
    lines.delete(line)
    log_change(change, user_id)
  end  
  


  #######################
  #
  def log_change(text, user_id)
    histories.create(:text => text, :user_id => user_id, :type_const => History::CHANGE) unless (user and user_id == user.id)
  end
  
  def log_history(text, user_id)
    histories.create(:text => text, :user_id => user_id, :type_const => History::ACTION)
  end
  
  def has_changes?
    history = histories.order('created_at DESC, id DESC').first
    history.nil? ? false : history.type_const == History::CHANGE
  end
  #
  #######################

end
