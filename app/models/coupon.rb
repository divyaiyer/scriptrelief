class Coupon < ActiveRecord::Base
  
  validates :name, :presence => true, :uniqueness => true, :length => { :maximum => 255 }
  validates :savings, :presence => true
  has_many :common_diseases_and_meds, :primary_key => :name, :foreign_key => :drug
  has_many :common_drug_and_generics, :primary_key => :name, :foreign_key => :drug
  has_many :common_drug_misspellings, :primary_key => :name, :foreign_key => :drug
  has_many :ratings, :primary_key => :id, :foreign_key => :coupon_id
  has_one  :coupon_content,:primary_key => :name,:foreign_key => :name
  
  define_index do
    # fields
    indexes :name , :as => :coupons_name, :facet => true
    indexes :savings , :as => :savings, :facet => true
    indexes :ailment , :as => :ailment, :facet => true
    indexes :thumb_loc , :as => :thumb_loc, :facet => true
    indexes :page_loc , :as => :page_loc, :facet => true
    indexes :new_savings  , :as => :new_savings, :facet => true
    indexes :priority , :as => :priority_coupon, :facet => true
    indexes :browse , :as => :browse_coupon, :facet => true
    indexes common_diseases_and_meds.diseases, :as => :cdam
    indexes common_drug_and_generics.generic, :as => :cdag
    indexes common_drug_misspellings.query, :as => :cdm
    
    has :id
    has :name
    has :priority
    has :browse
    has :created_at, :updated_at
    
    set_property :delta => :delayed
  end
  before_save :check_savings

  def check_savings
   if self.savings.scan("%").blank? && self.savings.scan("$").blank? 
    self.savings = !self.savings.scan(".").blank? ? (self.savings.to_f * 100).round(0).to_s + "%" : (self.savings + "%")
   end
  end
  
  def to_param
    "#{id}-#{self.name.parameterize}"
  end
end
