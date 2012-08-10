require 'csv'
class CouponsController < ApplicationController
  before_filter :require_user,:only=>[:index,:show,:new,:edit,:destroy,:update,:create,:userinfos]
  before_filter :call_api_flag , :only => [:prescription_discount_1,:prescription_discount_2,:prescription_discount_3,:prescription_discount_4,:prescription_discount_5,:prescription_discount_6,:prescription_discount, :print_prescription_discount, :spanish_prescription_discount]
  before_filter :set_source , :only => [:print_prescription_discount]
  before_filter :set_goog_old_flow , :only => [:prescription_discount]
  before_filter :before_prescription_discount, :only => [:prescription_discount_1,:prescription_discount_2,:prescription_discount_3,:prescription_discount_4,:prescription_discount_5,:prescription_discount_6,:prescription_discount, :email_prescription_discount, :sms_prescription_discount, :print_prescription_discount, :spanish_prescription_discount]
   layout "admin"

  def search
   name = params[:search] if params[:search]
   @per_page = 100
   session[:name] = name if !params[:page]
   @name = session[:name]
   @coupons = Coupon.paginate(:conditions => ['name LIKE ? ', '%'+@name+'%'],:per_page => @per_page, :page => params[:page])
   render :template=>'/coupons/index'
  end

  def ratings
    if cookies[:hlprx_ratings].blank?
     if params[:rating_sites]
      session[:ratings_name] = params[:rating_sites][:name]
       @rating_site = RatingSite.new(params[:rating_sites])
       respond_to do |format|
         if @rating_site.save
         cookies[:hlprx_ratings] = {:value =>"Rating added by #{request.env['REMOTE_ADDR']} ", :expires => Time.now + 90.days} if cookies[:hlprx_ratings].blank?
           session[:ratings_name] = ""
           @message = "Your ratings and review for the site has been successfully submitted."
           format.html {render :layout => false, :message => @message }
         else
           @err_msg = @rating_site.errors.full_messages
           format.html {render :layout => false, :message => "", :err_msg => @err_msg}
           format.xml  { render :xml => @rating_site.errors, :status => :unprocessable_entity }
         end
       end
     elsif params[:rating_coupons]
       @rating_coupon = RatingCoupon.new(params[:rating_coupons])
       respond_to do |format|
         if @rating_coupon.save
           rating_coupons = RatingCoupon.find(:all, :conditions => {:coupon_id => @rating_coupon.coupon_id})
             total_rate = 0
             rating_coupons.each do |r|
               total_rate = total_rate + r.rate
             end
             if rating_coupons.count == 0 then cnt = 1 else cnt = rating_coupons.count end
             avg = total_rate/cnt.to_f
             Coupon.update_all({:avg_rating => avg}, {:id => @rating_coupon.coupon_id})
             cookies[:hlprx_ratings] = {:value =>"Rating added by #{request.env['REMOTE_ADDR']} ", :expires => Time.now + 90.days} if cookies[:hlprx_ratings].blank?
           @message = "Your ratings and review for the coupon has been successfully submitted."
           format.html {render :layout => false, :message => @message }
         else
           @message = @rating_coupon.errors.full_messages
           format.html {render :layout => false, :message => @message}
           format.xml  { render :xml => @rating_coupon.errors, :status => :unprocessable_entity }
         end
       end
     else
       respond_to do |format|
         format.html {render :layout => false}
       end
     end
    else
      respond_to do |format|
         format.html {render :layout => false}
       end
   end
  end
  def pdf_download
        send_file("#{Rails.root}/public/monograph_pdf/#{params[:file]}")
  end

  def index
    @per_page = 100
    @search = params[:search] if params[:search]
    if params[:search]
      if params[:search][:top_coupon]
        @coupons = Coupon.paginate(:conditions=> ['top_coupon = ?', params[:search][:top_coupon]],:per_page => @per_page, :page => params[:page])
      end
    else
        @coupons = Coupon.paginate(:per_page => @per_page, :page => params[:page])
    end

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @coupons }
    end
  end

   def show
    @coupon = Coupon.find(params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @coupon }
    end
  end

   def new
    @coupon = Coupon.new

    respond_to do |format|
      format.html # new.html.erb
      format.xml  { render :xml => @coupon }
    end
  end

   def edit
    @coupon = Coupon.find(params[:id])
  end

   def create
    @coupon = Coupon.new(params[:coupon])

    respond_to do |format|
      if @coupon.save
        flash[:notice] = 'Coupon was successfully created.'
        format.html { redirect_to(coupons_url) }
        format.xml  { render :xml => @coupon, :status => :created, :location => @state }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @coupon.errors, :status => :unprocessable_entity }
      end
    end
  end

   def update
    @coupon = Coupon.find(params[:id])

    respond_to do |format|
      if @coupon.update_attributes(params[:coupon])
        flash[:notice] = 'Coupon was successfully updated.'
        format.html { redirect_to(coupons_url) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @coupon.errors, :status => :unprocessable_entity }
      end
    end
  end

   def destroy
    @coupon = Coupon.find(params[:id])
    @coupon.destroy

    respond_to do |format|
      format.html { redirect_to(coupons_url) }
      format.xml  { head :ok }
    end
  end

  def send_coupon_email
    email = params[:email]
    coupon = Coupon.find_by_id(params[:coupon_id])
    medicine = coupon.name if coupon
    discount = coupon.savings.strip.gsub('%','') if coupon
    subsource = cookies[:hlprx_utm_subsource]
    creative = cookies[:hlprx_utm_creative]
    source_tracking3 = cookies[:hlprx_utm_source]
    source,sourcekey = generate_source(source_tracking3)
    matchtype    = session[:matchtype]
    adid         = session[:adid]
    term         = session[:utm_term]
    browser      = get_browser(request.env['HTTP_USER_AGENT'].downcase)
    os           = get_operating_system(request.env['HTTP_USER_AGENT'].downcase)
    device       = get_device(request.env['HTTP_USER_AGENT'].downcase)
    searchstring = session[:searchstring]
    if !coupon.blank?
      options = {:coupon=>coupon.name,:savings=>coupon.savings.to_f,:searchstring=>searchstring,:browser=>browser,:os=>os,:device=>device,:ip=>request.env['REMOTE_ADDR'],:matchtype => matchtype,:adid => adid,:matchterm => term,:send_coupon_email => 'true', :source=>source,:sourcekey=>sourcekey, :subsource => subsource, :creative => creative, :prescription=> medicine, :email => email, :discount => discount}
      response     = get_coupon_value(options)
      @api_response = get_contact(response["Contacts"]) if response && response["Contacts"]
      cookies[:hlprx_prospect_id] = {:value => @api_response["ProspectId"], :expires => Time.now + 30.days} if @api_response && @api_response["ProspectId"]
      if !params[:userinfo_id].blank?
        Userinfo.update_all({:searchstring=>searchstring,:network=>cookies[:hlprx_network],:browser=>browser,:os=>os,:device=>device,:matchtype => matchtype,:adid => adid,:matchterm => term,:email => params[:email] ,:api_response=>(!response["Errors"].blank?||response["HasWarnings"]) ? (response["Errors"].join(',')+response["Warnings"].join(',')) : nil , :api_success =>response["Success"],:prospectid => cookies[:hlprx_prospect_id],:bin=>@api_response["BIN"],:pcn=>@api_response["PCN"],:member_number=>@api_response["MemberNumber"] },{:id => params[:userinfo_id]})
	##  update member number, BIN and PCN in the table.
      end
    end
      redirect_to email_helprx_signup_path(:u => params[:userinfo_id], :m => coupon.blank? ? "" : coupon.name, :email => email)
  end

  def send_coupon_sms
    number = params[:number]
    coupon = Coupon.find_by_id(params[:coupon_id])
    medicine = coupon.name if coupon
    discount = coupon.savings if coupon
    subsource = cookies[:hlprx_utm_subsource]
    creative = cookies[:hlprx_utm_creative]
    source_tracking3 = cookies[:hlprx_utm_source]
    source,sourcekey = generate_source(source_tracking3)
    matchtype = session[:matchtype]
    adid      = session[:adid]
    term      = session[:utm_term]
    browser   = get_browser(request.env['HTTP_USER_AGENT'].downcase)
    os        = get_operating_system(request.env['HTTP_USER_AGENT'].downcase)
    device    = get_device(request.env['HTTP_USER_AGENT'].downcase)
    searchstring = session[:searchstring]

    if !coupon.blank?
      options = {:coupon=>coupon.name,:savings=>coupon.savings.to_f,:searchstring=>searchstring,:browser=>browser,:os=>os,:device=>device,:ip=>request.env['REMOTE_ADDR'],:matchtype => matchtype,:adid => adid,:matchterm => term,:send_coupon_sms => 'true', :source=>source,:sourcekey=>sourcekey, :subsource => subsource, :creative => creative, :prescription=> medicine, :phone_number => number, :discount => discount}
      response     = get_coupon_value(options)
      @api_response = get_contact(response["Contacts"]) if response && response["Contacts"]
      cookies[:hlprx_prospect_id] = {:value => @api_response["ProspectId"], :expires => Time.now + 30.days} if @api_response && @api_response["ProspectId"]
      Userinfo.update_all({:searchstring=>searchstring,:network=>cookies[:hlprx_network],:browser=>browser,:os=>os,:device=>device,:matchtype => matchtype,:adid => adid,:matchterm => term,:mobile_number =>number, :api_response=>(!response["Errors"].blank?||response["HasWarnings"]) ? (response["Errors"].join(',')+response["Warnings"].join(',')) : nil, :api_success =>response["Success"],:prospectid => cookies[:hlprx_prospect_id],:bin=>@api_response["BIN"],:pcn=>@api_response["PCN"],:member_number=>@api_response["MemberNumber"] },{:id => params[:userinfo_id]})
      ##  update member number, BIN and PCN in the table.
    end
      redirect_to sms_helprx_signup_path(:u => params[:userinfo_id], :m => coupon.blank? ? "" : coupon.name)
  end

   def fulfillment
    @coupon = Coupon.find_by_name(params[:coupon].strip.gsub('_','/')) if !params[:coupon].blank? && params[:id].blank?
    @coupon = Coupon.find_by_id(params[:id]) if !params[:id].blank? && params[:coupon].blank?
    cookies[:hlprx_utm_creative] = {:value => 'fulfill', :expires => Time.now + 1.days}
    if !@coupon.blank?
        render :template=>'/coupons/fulfillment/',:layout => false
    else
      redirect_to discounts_path
    end
  end

  def fulfillment_print
    cookies[:hlprx_utm_creative] = {:value => 'fulfill2', :expires => Time.now + 1.days}
    if !@coupon.blank?
        render :template=>'/coupons/fulfillment_print/',:layout => false
    else
      redirect_to discounts_path
    end
  end

  def fulfillment_option
    @coupon = Coupon.find_by_name(params[:coupon].strip.gsub('_','/')) if !params[:coupon].blank? && params[:id].blank?
    @coupon = Coupon.find_by_id(params[:id]) if !params[:id].blank? && params[:coupon].blank?
    @medicine = @coupon.name if @coupon
    @discount = @coupon.savings if @coupon
    prefix = "HNA"
    usernumber = Userinfo.maximum('id') + 1
    @api_response = {"BIN"=>$BIN, "PCN"=>$PCN, "GroupNumber"=>$GRP, "MemberNumber"=>prefix+usernumber.to_s.rjust(6,"0")}
    if cookies[:helprx_new_fulfill].blank?
        cookies[:hlprx_utm_creative] = {:value => 'fulfill', :expires => Time.now + 1.days}
        render :template=>'/coupons/fulfillment/',:layout => false
    else
      cookies[:hlprx_utm_creative] = {:value => 'fulfill2', :expires => Time.now + 1.days}
      render :template=>'/coupons/fulfillment_print/',:layout => false
    end
  end

  def email_prescription_discount
    if !@coupon.blank?
        render :template=>'/coupons/email_prescription_discount/',:layout => false
    else
      redirect_to email_discounts_path
    end
  end

  def sms_prescription_discount
    if !@coupon.blank?
        render :template=>'/coupons/sms_prescription_discount/',:layout => false
    else
      redirect_to sms_discounts_path
    end
  end

  def print_prescription_discount
    if !@coupon.blank?
        render :template=>'/coupons/print_prescription_discount/',:layout => false
    else
      redirect_to print_discounts_path
    end
  end

  def spanish_prescription_discount
    if !@coupon.blank?
        render :template=>'/coupons/spanish_prescription_discount/',:layout => false
    else
      redirect_to email_discounts_path
    end
  end
  def prescription_discount
    if !@coupon.blank?
      if cookies[:hlprx_print] == "HrxControl"
        render :template=>'/coupons/prescription_discount/',:layout => false
      elsif cookies[:hlprx_print] == "A"
        render :template=>'/coupons/prescription_discount_2/',:layout => false
      elsif cookies[:hlprx_print] == "B"
        render :template=>'/coupons/prescription_discount_4/',:layout => false
      else
       render :template=>'/coupons/prescription_discount/',:layout => false
      end
    else
      redirect_to "/"
    end
  end

  def prescription_discount_1
    if !@coupon.blank?
        render :template=>'/coupons/prescription_discount_1/',:layout => false
    else
      redirect_to "/"
    end
  end
  def prescription_discount_2
    if !@coupon.blank?
        render :template=>'/coupons/prescription_discount_2/',:layout => false
    else
      redirect_to "/"
    end
  end
  def prescription_discount_3
    if !@coupon.blank?
        render :template=>'/coupons/prescription_discount_3/',:layout => false
    else
      redirect_to "/"
    end
  end
  def prescription_discount_4
    if !@coupon.blank?
        render :template=>'/coupons/prescription_discount_4/',:layout => false
    else
      redirect_to "/"
    end
  end
 
  def prescription_discount_5
   if !@coupon.blank?
       render :template=>'/coupons/prescription_discount_5/',:layout => false
   else
     redirect_to "/"
   end
  end

  def prescription_discount_6
   if !@coupon.blank?
       render :template=>'/coupons/prescription_discount_6/',:layout => false
   else 
     redirect_to "/"
   end
  end

  def lifescript_prescription_discount
    @m = params[:m]
    @coupon = Coupon.find_by_name(params[:coupon].gsub('_','/')) if !params[:coupon].blank? && params[:id].blank?
    @coupon = Coupon.find_by_id(params[:id]) if !params[:id].blank? && params[:coupon].blank?
    @medicine = @coupon.name if @coupon
    @discount = @coupon.savings if @coupon
    if params[:sourceid]
      @sourceid = '&sourceid='+ params[:sourceid]
    else
      @sourceid = ''
    end
    if !session[:uid]
      session[:uid] = UUIDTools::UUID.random_create.to_s
    end
    userinfo = Userinfo.find_by_id(params[:transferred_datum_id])
    source_tracking1 = cookies[:hlprx_utm_campaign]
    source_tracking2 = cookies[:hlprx_utm_medium]
    source_tracking3 = userinfo.source_tracking3 || cookies[:hlprx_utm_source]
    subsource = cookies[:hlprx_utm_subsource]
    creative = cookies[:hlprx_utm_creative]
    uid = session[:uid]
    matchtype = session[:matchtype]
    adid      = session[:adid]
    term      = session[:utm_term]
    browser   = get_browser(request.env['HTTP_USER_AGENT'].downcase)
    os        = get_operating_system(request.env['HTTP_USER_AGENT'].downcase)
    device    = get_device(request.env['HTTP_USER_AGENT'].downcase)
    searchstring = session[:searchstring]
    source,sourcekey = generate_source(source_tracking3)
      id                = userinfo.blank? ? "" : userinfo.id
    if !@coupon.blank?
      options = {:lifescript_print => "lifescript_print",:coupon=>@coupon.name,:savings=>@coupon.savings.to_f,:searchstring=>searchstring,:browser=>browser,:os=>os,:device=>device,:ip=>request.env['REMOTE_ADDR'],:matchtype => matchtype,:adid => adid,:matchterm => term,:id=>id,:source=>source,:sourcekey=>sourcekey,:sourcetracking1=>source_tracking1,:sourcetracking2=>source_tracking2,:prescription=>@coupon.name, :subsource => subsource, :creative => creative}
      response          = get_coupon_value(options)
      @api_response     = get_contact(response["Contacts"]) if response && response["Contacts"]
      cookies[:hlprx_prospect_id] = {:value => @api_response["ProspectId"], :expires => Time.now + 30.days} if @api_response && @api_response["ProspectId"]

      userinfo.update_attributes(:searchstring=>searchstring,:network=>cookies[:hlprx_network],:browser=>browser,:os=>os,:device=>device,:matchtype => matchtype,:adid => adid,:matchterm => term,:api_response=>(!response["Errors"].blank?||response["HasWarnings"]) ? (response["Errors"].join(',')+response["Warnings"].join(',')) : nil,
      :api_success =>response["Success"] ,:userid => uid,:pcn=>@api_response["PCN"].upcase,:bin=>@api_response["BIN"],
      :member_number=>@api_response["MemberNumber"],:grpcode=>@api_response["GroupNumber"],:rx=>@coupon.name,
      :prescription_id=>@coupon.id,:url=>request.referer,:discounts=>@coupon.savings,:source=>source,
      :source_tracking1=>source_tracking1,:source_tracking2=>source_tracking2,:source_tracking3=>source_tracking3, :subsource => subsource, :creative => creative,:prospectid => cookies[:hlprx_prospect_id]) if !userinfo.blank?
      cookies[:hlprx_visit_id] = {:value => userinfo.id, :expires => Time.now + 1.days}  if cookies[:hlprx_visit_id].blank?
      respond_to do |format|
        format.html {render :layout => false }
      end
    else
      redirect_to "/"
    end
  end

  def before_prescription_discount
    @m = params[:m]
    @coupon = Coupon.find_by_name(params[:coupon].strip.gsub('_','/')) if !params[:coupon].blank? && params[:id].blank?
    @coupon = Coupon.find_by_id(params[:id]) if !params[:id].blank? && params[:coupon].blank?
    @medicine = @coupon.name if @coupon
    @discount = @coupon.savings if @coupon
    if params[:sourceid]
      @sourceid = '&sourceid='+ params[:sourceid]
    else
      @sourceid = ''
    end
    if !session[:uid]
      session[:uid] = UUIDTools::UUID.random_create.to_s
    end
    source_tracking1 = cookies[:hlprx_utm_campaign]
    source_tracking2 = cookies[:hlprx_utm_medium]
    source_tracking3 = cookies[:hlprx_utm_source]
    subsource = cookies[:hlprx_utm_subsource]
    creative = cookies[:hlprx_utm_creative]
    matchtype = session[:matchtype]
    adid      = session[:adid]
    term      = session[:utm_term]
    browser   = get_browser(request.env['HTTP_USER_AGENT'].downcase)
    os        = get_operating_system(request.env['HTTP_USER_AGENT'].downcase)
    device    = get_device(request.env['HTTP_USER_AGENT'].downcase)
    searchstring = session[:searchstring]
    uid = session[:uid]
    #Always getting BIN/PCN/MID/GRP from MemberId API call . If utm_source is not present taking the default as 'helporganic'
    @api_response = {}
    source,sourcekey = generate_source
    source = @source if @source
     if request.path.include?("/email")
       printing_type = 'email'
       @email        = true
     elsif request.path.include?("/sms")
       printing_type = 'sms'
       @sms          = true
     elsif request.path.include?("/printable_discount/")
       printing_type = 'print'
     end
    
    if !@coupon.blank?
      if (@call_api == true)
        options = {:coupon => @coupon.name, :savings => @coupon.savings.to_f, :searchstring => searchstring, :browser => browser, :os => os, :device => device, :ip => request.env['REMOTE_ADDR'], :matchtype => matchtype, :adid => adid, :matchterm => term, :send_coupon_sms => (@sms ? true : false), :send_coupon_email => (@email ? true : false), :id => nil, :source => source, :sourcekey => sourcekey, :sourcetracking1 => source_tracking1, :sourcetracking2 => source_tracking2, :prescription => @coupon.name, :subsource => subsource, :creative => creative}
        response = get_coupon_value(options)
        @api_response = get_contact(response["Contacts"]) if response && response["Contacts"]
        cookies[:hlprx_prospect_id] = {:value => @api_response["ProspectId"], :expires => Time.now + 30.days} if @api_response && @api_response["ProspectId"]
      else
        response = {}
        #@api_response  = deafult_api_values(source,sourcekey) #Need to confirm this. Wheteher sms/email preview has git default prefix of HNA or based on utm if present
        @api_response = {"BIN" => $BIN, "PCN" => $PCN, "GroupNumber" => $GRP}
      end
      @api_response = {"BIN" => $BIN, "PCN" => $PCN, "GroupNumber" => $GRP} if @api_response.blank?
      optional_params = {"searchstring"=>searchstring,"browser"=>browser,"os"=>os,"device"=>device,"matchtype" => matchtype,"adid" => adid,"matchterm" => term,"printing_type" => printing_type,"api_response"=>(!response["Errors"].blank?||response["HasWarnings"]) ? (response["Errors"].join(',')+response["Warnings"].join(',')) : nil,"api_success" =>response["Success"] ,"partner" => source_tracking3,"uid" => uid,"grpcode"=>@api_response["GroupNumber"],"bin"=>@api_response["BIN"],
      "pcn"=>@api_response["PCN"],"prescription_id"=>@coupon.id,"url"=>request.referer,"ip_address"=>request.env['REMOTE_ADDR'],"source"=>source,
      "discount"=>@coupon.savings,"member_number"=>@api_response["MemberNumber"],"source_tracking1"=>source_tracking1,"source_tracking2"=>source_tracking2,
      "source_tracking3"=>source_tracking3,"visit_id" => cookies[:hlprx_visit_id],"prospect_id" => cookies[:hlprx_prospect_id], "subsource" => subsource, "creative" => creative}
    @usernumber = add_user_info(@medicine,optional_params) if !@bot_request
    number      = @usernumber.blank? ? {:id =>(Userinfo.maximum('id') + 1)} : @usernumber
    @api_response["MemberNumber"] = "HNA"+number[:id].to_s.rjust(6,"0") if @api_response && @api_response["MemberNumber"].blank?
   cookies[:hlprx_visit_id] = {:value => @usernumber.id, :expires => Time.now + 1.days}  if cookies[:hlprx_visit_id].blank? && !@bot_request
    end
  end

  def call_api_flag
    @call_api = true
  end

  def set_goog_old_flow
    if (cookies[:hlprx_goog_old])
      @source = "helpgoog3"
    end
  end

  def set_source
    @source = "helpgoog2"
  end

  def add_user_info(medicine, options)
    userinfo = Userinfo.new
    userinfo.grpcode = options["groupno"]
    userinfo.rx = medicine
    userinfo.userid = options["uid"]
    userinfo.vid = options["visit_id"]
    userinfo.prospectid = options["prospect_id"].to_i
    userinfo.source_tracking1 = options["source_tracking1"]
    userinfo.source_tracking2 = options["source_tracking2"]
    userinfo.source_tracking3 = options["source_tracking3"]
    userinfo.ip_address = options["ip_address"]
    userinfo.member_number = options["member_number"]
    userinfo.source = options["source"]
    userinfo.subsource = options["subsource"]
    userinfo.creative = options["creative"]
    userinfo.discounts = options["discount"]
    userinfo.prescription_id = options["prescription_id"]
    userinfo.url = options["url"]
    userinfo.bin = options["bin"]
    userinfo.pcn = options["pcn"]
    userinfo.grpcode = options["grpcode"]
    userinfo.partner = options["partner"]
    userinfo.api_success = options["api_success"]
    userinfo.api_response = options["api_response"]
    userinfo.printing_type = options["printing_type"]
    userinfo.matchtype = options["matchtype"]
    userinfo.adid = options["adid"]
    userinfo.searchstring = options["searchstring"]
    userinfo.matchterm = options["matchterm"]
    userinfo.network = options["network"]
    userinfo.device = options["device"]
    userinfo.browser = options["browser"]
    userinfo.os = options["os"]
    userinfo.network = cookies[:hlprx_network]
    userinfo.save
    return userinfo
  end

end
