class CommonDiseasesAndMed < ActiveRecord::Base
  validates :diseases,  :presence => :true, :length => { :maximum => 255 }
  validates :drug,  :presence => :true,  :length => { :maximum => 255 }
  validates :works,  :presence => :true
end

