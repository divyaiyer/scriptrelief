class DiscountsController < ApplicationController
  #before_filter :check_if_mobile?, :only => :index
  before_filter :before_index, :only => [:index, :email_index, :sms_index, :print_index,:fulfill_index]
  def search
    sphinx_keywords = SphinxKeyword.find( :all, :conditions => [" keyword LIKE ?", "#{ params[:term] }%"], :order => "keyword ASC", :limit => 10)
    coupons = Coupon.search params[:term] + "*",  :limit => 10
    if params[:type] && params[:type] == "simple"
      list = sphinx_keywords.map {|u| Hash[:id =>  u.id, :label =>  u.keyword]}
      list += coupons.map {|u| Hash[ :id => u.id, :label =>  u.name]}
    else
      list = sphinx_keywords.map {|u| Hash[ :id => u.id, :label =>  u.keyword, :name =>  "Keywords", :category => "Keywords"]}
      list += coupons.map {|u| Hash[ :id => u.id, :label => u.name, :name => "Brands", :category => "Brands"]}
    end
    respond_to do |format|
      format.json {render :json => list}
    end
  end

  def simple_search
    coupons = Coupon.search params[:term] + "*",  :limit => 10
    list = coupons.map {|u| Hash[ :id => u.id, :label => u.name]}
    respond_to do |format|
      format.json {render :json => list}
    end
  end

  def iframed_index
    if params[:search] && params[:search].is_a?(String)
      @search = params[:search]
    elsif params[:search] && params[:search][:name]
      @search = params[:search][:name]
    end
    session[:matchtype]    =  params[:matchtype] ? params[:matchtype] : session[:matchtype]
    session[:adid]         =  params[:adid] ? params[:adid] : session[:adid]
    session[:utm_term]     =  params[:utm_term] ?params[:utm_term] :  session[:utm_term]
    session[:searchstring] = check_searchstring
  	name = inner_search_text(@search)
      	@per_page = 10
        params[:alphabet_search] = "true" if @search && @search.length == 1
        @params_order = "name ASC"
      if @search.blank?
          @coupons = Coupon.search :conditions => { :browse_coupon => 1 },:per_page =>@per_page, :page => params[:page], :order => "priority ASC"
      else
        if params[:alphabet_search]!="true"
          @coupons = Coupon.search(name+"*",:per_page =>@per_page, :page => params[:page], :order => "@relevance DESC,name ASC")
        else
          search_term = "\"^#{name}$\"|\"^#{name}*\""
          @coupons =  Coupon.search :conditions => {:coupons_name =>search_term, :browse_coupon => 1 },:per_page =>@per_page, :page => params[:page], :order => "priority ASC"
        end
      end
      if @coupons.blank?
        suggest = suggestions(name)
        @suggest = suggest
      end
      if @suggest.blank? or params[:redirect]==true
        respond_to do |format|
          format.html {render :search => @search , :layout => false}
          format.js { render :partial => "iframe_coupons"}
        end
      else
          redirect_to("/tools/discounts?search=#{@suggest}&redirect=true")
      end
  end


  def iframed_index_spanish
      if params[:search] && params[:search].is_a?(String)
        @search = params[:search]
      elsif params[:search] && params[:search][:name]
        @search = params[:search][:name]
      end
      session[:matchtype]    =  params[:matchtype] ? params[:matchtype] : session[:matchtype]
      session[:adid]         =  params[:adid] ? params[:adid] : session[:adid]
      session[:utm_term]     =  params[:utm_term] ?params[:utm_term] :  session[:utm_term]
      session[:searchstring] = check_searchstring
      name = inner_search_text(@search)   if @search
      @per_page = 10
      params[:alphabet_search] = "true" if @search && @search.length == 1
      @params_order = "name ASC"
      if @search.blank?
          @coupons = Coupon.search :conditions => { :browse_coupon => 1 },:per_page =>@per_page, :page => params[:page], :order => "priority ASC"
      else
        if params[:alphabet_search]!="true"
          @coupons = Coupon.search(name+"*",:per_page =>@per_page, :page => params[:page], :order => "@relevance DESC,name ASC")
        else
          search_term = "\"^#{name}$\"|\"^#{name}*\""
            @coupons =  Coupon.search :conditions => {:coupons_name =>search_term, :browse_coupon => 1 },:per_page =>@per_page, :page => params[:page], :order => "priority ASC"
        end
      end
      if @coupons.blank?
        suggest = suggestions(name)
        @suggest = suggest
      end

      if @suggest.blank? or params[:redirect]==true
        respond_to do |format|
          format.html {render :search => @search , :layout => false}
          format.js { render :partial => "iframe_spanish_coupons"}
        end
      else
          redirect_to("/esp/tools/discounts?search=#{@suggest}&redirect=true")
      end
  end

  def fulfill_index
    @show_msg = params[:show_msg] if !params[:show_msg].blank?
    if @suggest.blank? or params[:redirect]==true
      respond_to do |format|
        format.html {render :search => @search }
        format.js { render :partial => "fulfill_coupons"}
      end
    else
      redirect_to("/fulfill/discounts?search=#{@suggest}&redirect=true")
    end
  end
  def email_index
    if @suggest.blank? or params[:redirect]==true
      respond_to do |format|
        format.html {render :search => @search , :layout => "application_new_nav"}
        format.js { render :partial => "email_coupons"}
      end
    else
      redirect_to("/email/discounts?search=#{@suggest}&redirect=true")
    end
  end
  
  def sms_index
    if @suggest.blank? or params[:redirect]==true
      respond_to do |format|
        format.html {render :search => @search, :layout => "application_new_nav" }
        format.js { render :partial => "sms_coupons"}
      end
    else
      redirect_to("/sms/discounts?search=#{@suggest}&redirect=true")
    end
  end
  
  def print_index
    if @suggest.blank? or params[:redirect]==true
      respond_to do |format|
        format.html {render :search => @search , :layout => "application_new_nav"}
        format.js { render :partial => "print_coupons"}
      end
    else
      redirect_to("/print/discounts?search=#{@suggest}&redirect=true")
    end
  end
  
  def index
    @show_msg = params[:show_msg] if !params[:show_msg].blank?
    if @suggest.blank? or params[:redirect]==true
      respond_to do |format|
        format.html {render :search => @search }
        format.js { render :partial => "coupons"}
      end
    else
      redirect_to("/discounts?search=#{@suggest}&redirect=true")
    end
  end

  def thanks_submit
    if params[:transferred_data]
      coupon = Coupon.find_by_name(params[:transferred_data][:current_prescription])
      userinfo = Userinfo.create(:firstname => params[:transferred_data][:firstname],:lastname => params[:transferred_data][:lastname],:email => params[:transferred_data][:email],:address1=> params[:transferred_data][:address1],:address2 => params[:transferred_data][:address2],:city => params[:transferred_data][:city],:state => params[:transferred_data][:state],:zip => params[:transferred_data][:zip],:pcn => params[:transferred_data][:pcn],:bin => params[:transferred_data][:bin],:url => params[:transferred_data][:url],:ip_address => params[:transferred_data][:remote_ip],:rx => params[:transferred_data][:current_prescription],:grpcode => params[:transferred_data][:groupno], :discounts => (coupon.savings if !coupon.blank?),:prescription_id => (coupon.id if !coupon.blank?),:path=>params[:transferred_data][:path], :vid => cookies[:hlprx_visit_id])
      if userinfo.save
        cookies[:hlprx_visit_id] = {:value => userinfo.id, :expires => Time.now + 1.days}  if cookies[:hlprx_visit_id].blank?
        respond_to do |format|
          format.html
          format.xml
        end
      else
        respond_to do |format|
          format.html {render :action => "index", :object => {:transfered_data => @transfered_data}}
          format.xml
        end
      end
    end
  end

  protected
  
  def check_searchstring
     if params[:search] && params[:search].is_a?(String)
       session[:searchstring] = params[:search]
     elsif params[:search] && params[:search][:name]
       session[:searchstring] = params[:search][:name]
     else
       session[:searchstring] = nil
     end
    return session[:searchstring]
   end
   def inner_search_text(name)
    return '' if (name.blank?)
    return Riddle.escape(name).gsub(/[^a-zA-Z0-9\-\,\%\.\/\s]*/, '')
  end

  def build_trigrams(keyword)
    keyword = "__" + keyword + "__"
    trigrams = ""
    i = 0
    while i < keyword.length - 2  do
      trigrams = trigrams + keyword[i..(i+2)] + " "
      i +=1;
    end
    trigrams
  end


  def suggestions(keyword)
    trigrams = build_trigrams(keyword)
    select = "*, @weight + 2 -abs(len - #{keyword.length}) + ln(freq)/ln(1000) AS myrank"
    results = SphinxSuggest.search trigrams, :sphinx_select => select, :with => {:len => (keyword.length - 3)..(keyword.length + 3)}, :match_mode => :any ,:sort_mode => :extended, :order => "myrank DESC, freq ASC", :limit => 10
    for result in results
      key = result.keyword
      if Text::Levenshtein.distance(keyword, result.keyword) <= 5#$LEVENSHTEIN_THRESHOLD
        return key
      end
    end
    return ""
  end
  
  def before_index
    @page_title='Pharmacy Discounts - HelpRx.info'
      if params[:search] && params[:search].is_a?(String)
        @search = params[:search]
      elsif params[:search] && params[:search][:name]
        @search = params[:search][:name]
      end
    session[:matchtype]    =  params[:matchtype] ? params[:matchtype] : session[:matchtype]
    session[:adid]         =  params[:adid] ? params[:adid] : session[:adid]
    session[:utm_term]     =  params[:utm_term] ?params[:utm_term] :  session[:utm_term]
    session[:searchstring] = check_searchstring
    name = inner_search_text(@search)   if @search 
    @per_page = 10
    params[:alphabet_search] = "true" if @search && @search.length == 1
    @params_order = "name ASC"
    if @search.blank?
        @coupons = Coupon.search :conditions => { :browse_coupon => 1 },:per_page =>@per_page, :page => params[:page], :order => "priority ASC"        
    else
      if params[:alphabet_search]!="true"
        @coupons = Coupon.search(name+"*",:per_page =>@per_page, :page => params[:page], :order => "@relevance DESC,name ASC")
        @coupon_content = CouponContent.find_by_name(@coupons[0].name) if !@coupons.blank?
      else
        search_term = "\"^#{name}$\"|\"^#{name}*\""
          @coupons =  Coupon.search :conditions => {:coupons_name =>search_term, :browse_coupon => 1 },:per_page =>@per_page, :page => params[:page], :order => "priority ASC"          
      end
    end
    if @coupons.blank?
      suggest = suggestions(name)
      @suggest = suggest
    end
  end

end

