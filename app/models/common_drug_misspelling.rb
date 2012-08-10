class CommonDrugMisspelling < ActiveRecord::Base
   validates :query,  :presence => :true,  :length => { :maximum => 255 }
  validates :drug,  :presence => :true,  :length => { :maximum => 255 }
  validates :works,  :presence => :true
end

