class SphinxKeyword < ActiveRecord::Base
  validates :keyword,  :length => { :maximum => 255 }
  validates :freq,  :length => { :maximum => 11}
end
