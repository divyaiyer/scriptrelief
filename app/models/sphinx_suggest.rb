class SphinxSuggest < ActiveRecord::Base
  define_index do
    # fields
    indexes :keyword , :as => :sphinx_keyword, :facet => true
    indexes :trigrams , :as => :trigrams, :facet => true
    has :id, :freq, :len
    has :keyword
    has :created_at, :updated_at
  end
  
   def self.build_trigrams(keyword)
    keyword = "__" + keyword + "__"
    trigrams = ""
    i = 0
    while i < keyword.length - 2  do
      trigrams = trigrams + keyword[i..(i+2)] + " "
      i +=1;
    end
    trigrams.downcase
    end

end
