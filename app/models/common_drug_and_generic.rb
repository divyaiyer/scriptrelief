class CommonDrugAndGeneric < ActiveRecord::Base
  validates :generic,  :presence => :true,  :length => { :maximum => 255 }
  validates :drug,  :presence => :true,  :length => { :maximum => 255 }
  validates :works,  :presence => :true
end

