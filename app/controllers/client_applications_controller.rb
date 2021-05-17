require 'net/http'
require 'uri'
require 'json'
require "kafka"

class ClientApplicationsController < ApplicationController
  include ClientApplicationsHelper
  include UsersHelper
  before_action :set_client_application, only: [:show, :edit, :update, :destroy]
  before_action :authenticate_user!, except: [:new, :create, :contact_management]
 skip_before_action :verify_authenticity_token, only: [:send_for_approval, :approve_catalog, :upload_countersign_doc]
  # GET /client_applications
  # GET /client_applications.json
  def index  
    user = current_user
    user.active_otp = ""
    user.save!
    logger.debug("-UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU #{user.inspect}")
    @client_application = current_user.client_application
    @registration_request = RegistrationRequest.all
    @notification_rules = @client_application.notification_rules
    @referred_applications = LedgerStatus.where(referred_application_id: @client_application.id.to_s)
    # @referred_applications.each do |ra|
    #   ledger_master = ra.ledger_master
    #   logger.debug("the ledger master is : #{ra.inspect}")
    #   task = Task.find(ledger_master.task_id)
    # end
    @about = AboutU.where(client_application_id: @client_application.id.to_s).entries
    @faqs = Faq.where(client_application_id: @client_application.id.to_s).entries
    # @referred_applications = LedgerStatus.all

    logger.debug("the session count is *********************: #{user.sign_in_count}, LEDGER STATIS : #{@referred_applications.entries}")
    logger.debug("the params are *********************: #{params.inspect}")
    if user.sign_in_count.to_s == "1" && user.admin == true
      # rr = RegistrationRequest.find_by(user_email: user.email)
      # rr.invitation_accepted = true
      # rr.save
      if @client_application.external_application == true
        logger.debug("REDIRECTING TO THE API STEPS for EXTERNAL APPLICATION ****************")
        # redirect_to after_signup_external_path(:api_setup)
        redirect_to after_signup_external_index_path

      else
        logger.debug("REDIRECTING TO THE NEW STEPS****************")
        redirect_to after_signup_path(:role)
      end
    elsif user.sign_in_count.to_s == "1"
      #mailer Story 405
      adminUser = User.where(admin: true, client_application_id: @client_application.id).first
      NotificationMailer.alertPendingContactJoined(user, adminUser).deliver
      ##
    end 
    ## To Be. Background Job check_expiration_date
    all_ca = ClientApplication.all

      all_ca.each do |ca|
        if ca.client_agreement_expiration == Date.today
          ca.agreement_signed = false
          ca.agreement_counter_sign = "Pending"
        else 
        end 

      end 
  end

  # GET /client_applications/1
  # GET /client_applications/1.json
  def show
    @contact_details = current_user.client_application
  end

  # GET /client_applications/new
  def new
    @client_application = ClientApplication.new
  end

  # GET /client_applications/1/edit
  def edit

  end

  # POST /client_applications
  # POST /client_applications.json
  def create
    # @client_application.logo = params['client_application']['logo']
    # @client_application.save
    logger.debug("************THE PARAMETERS IN create Client Applicaiton ARE: #{params.inspect}")
    @client_application = ClientApplication.new(client_application_params)
    respond_to do |format|
      if @client_application.save
        admin_role = Role.create(client_application_id: @client_application.id.to_s ,role_name: "Admin", role_abilities: [{"action"=>[:manage], "subject"=>[:all]}])
       if params[:client_application][:user][:email]
         user_invite = send_invite_to_user(params[:client_application][:user][:email],@client_application,
                                           params[:client_application][:user][:name], admin_role.id.to_s )
       end
        format.html { redirect_to @client_application, notice: 'Client application was successfully created.' }
        format.json { render :show, status: :created, location: @client_application }
      else
        format.html { render :new }
        format.json { render json: @client_application.errors, status: :unprocessable_entity }
      end
    end
  end

  def send_invite_to_user(email, client_application,name,role)
    logger.debug("********* In the send user invite method")
    @user = User.invite!(email: email, name: name,roles: [role])
    @user.update(client_application_id: client_application , application_representative: true, admin: true)
  end

  def register_client
    @client_application = ClientApplication.new
  end
  # PATCH/PUT /client_applications/1
  # PATCH/PUT /client_applications/1.json
  def update
    @client_application.logo = params['client_application']['logo']
    @client_application.theme = params['theme']
    @client_application.save
    respond_to do |format|
      if @client_application.update(client_application_params)
        logger.debug("IN THE APPLICATION UPDATE*************************")
        format.html { redirect_to @client_application, notice: 'Client application was successfully updated.' }
        format.json { render :show, status: :ok, location: @client_application }
      else
        format.html { render :edit }
        format.json { render json: @client_application.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /client_applications/1
  # DELETE /client_applications/1.json
  def destroy
    @client_application.destroy
    respond_to do |format|
      format.html { redirect_to client_applications_url, notice: 'Client application was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def all_details
    # @client_application = @client_application
    user = current_user
    logger.debug("*********************************************************THE CURRENT USER IS : #{user}")
    @client_application = current_user.client_application 

  end

  def save_all_details

    @client_application = current_user.client_application
    if params[:client_application][:client_agreement].present?
      logger.debug("IN the counter sign if statement**************************")
      @client_application.agreement_counter_sign = "Pending"
      @client_application.agreement_signed = false
 
      @client_application.save
    end
    @client_application.update(client_application_params)
    redirect_to root_path
  end

  def send_application_invitation
    logger.debug("*************the id is: #{params[:id]}")
    rr = RegistrationRequest.find(params[:id])

    ca = ClientApplication.new
    ca.name = rr.application_name
    ca.application_url = rr.application_url
    ca.external_application = rr.external_application
    ca.master_application_status = false

    if ca.save
      admin_role = Role.create(client_application_id: ca.id.to_s ,role_name: "Admin", role_abilities: [{"action"=>[:manage], "subject"=>[:all]}])
      if rr.user_email
        user_invite = send_invite_to_user(rr.user_email,ca,
                                          rr.application_name, admin_role.id.to_s )
        logger.debug("the user Invite value is : #{user_invite} -------#{user_invite.class}")
        if user_invite == true
          rr.invited = true
          rr.save
        end
      end
    end

  end


  def send_application_prep_request
    rr = RegistrationRequest.find(params[:id])

    name = rr.application_name

    RegistrationRequestMailer.send_application_prep( name ).deliver


  end

  def master_provider
    results = []
    dynamodb = Aws::DynamoDB::Client.new(region: "us-west-2")

    # table_name = 'master_provider'
    table_name = ENV["MASTER_TABLE_NAME"]

    params = {
        table_name: table_name,
        # projection_expression: "url",
        # filter_expression: "url = test1.com"
    }

    # result = dynamodb.scan(params)[:items] #.sort_by!{|k| k["created_at"]}.reverse!
    result = dynamodb.scan(params) #.sort_by!{|k| k["created_at"]}.reverse!

    loop do

      # logger.debug("*************************the count of the iteration is : #{result.items.count}, and the result is : #{result}")
      results << result.items

      break unless (lek = result.last_evaluated_key)

      result = dynamodb.scan params.merge(exclusive_start_key: lek)

    end

    @result = results.flatten

    # @pending_results = @result.select{|p| p["status"] == "Pending"}
    # @rules_url = ScrapingRule.where(:changed_fields.ne => nil).pluck(:url)
    rules = ScrapingRule.nin(changed_fields: [[],nil])
    rules.each do |r|
      keys_present = []
      rule_changes = r.changed_fields
      rule_changes.each do |cr|
        keys_present.push(cr.keys)
      end

    end

    @rules_url = rules.pluck(:url)


    logger.debug("the RESULT OF THE SCAN IS : ************************ {@result}")

    #@masterStatus = @client_application.master_application_status

    # user = current_user
    # @client_application = current_user.client_application
    # @masterStatus = @client_application.master_application_status
  end

  def contact_management
    # dynamodb = Aws::DynamoDB::Client.new(region: "us-west-2")
    #
    # table_name = 'contact_management'
    # params = {
    #     table_name: table_name,
    #     # projection_expression: "url",
    #     # filter_expression: "url = test1.com"
    # }
    #
    # @result = dynamodb.scan(params)[:items] #.sort_by!{|k| k["created_at"]}.reverse!

    @result = helpers.catalog_table_content

    #logger.debug("***********************the the count in the result is : #{@result.count}")
 
    @pending_results = @result.select{|p| p["status"] == "Pending"}

    #logger.debug("the RESULT OF THE SCAN IS : ************************ #{@pending_results}")

    #@masterStatus = @client_application.master_application_status

    @sr_urls = ScrapingRule.all.pluck(:url)
    #logger.debug("the sr ursls are  : ************************ #{@sr_urls}")
    user = current_user
    @client_application = current_user.client_application
    @masterStatus = @client_application.master_application_status


  end

  def invalid_catalog_management
    @invalid_catalog = InvalidCatalogEntry.all
  end





  def new_site_adding

    if params["catalog_data"]

      logger.debug("*************IN the mang VIEWER CONTROLER  CATALOG DATA***********")

      @result = JSON.parse(params[:catalog_data])
      new_site_id = @result["OrgSites"].blank? ? "1" : (@result["OrgSites"].collect {|s| s["SelectSiteID"].to_i}.sort.last + 1).to_s
      logger.debug("the new site ids are: #{new_site_id}")

      # @result = params[:catalog_data]

      new_site = {"InactiveSite"=>false, "LocationName"=>"", "AddrState"=>"", "AddrCity"=>"",
                  "AddrZip"=>"", "ServiceDeliverySite"=>true, "AdminSite"=>false, "ResourceDirectory"=>false, "SelectSiteID"=> new_site_id,
                  "DefaultPOC"=>false, "InactivePOC"=>false, "OfficePhone"=>"", "Name"=>"",
                  "POCs"=>[{"id"=>"1.0", "poc"=>{"DefaultPOC"=>false, "InactivePOC"=>false, "OfficePhone"=>"",
                  "Name"=>""}}], "Addr1"=>[{"Xpath"=>"", "Text"=>"", "Domain"=>""}]}
      # logger.debug("THE ORG SITE IS #{@result["OrgSites"]}-------------#{new_site.class}")
      @result["OrgSites"].append(new_site)

      details = cat_details(@result)

      @url = details[:url]
      #logger.debug("WHAT IS THE URL  #{@url}")
      @orgDetails = details[:OrgDetails]
      # sets default org desc display if don't exists
      set_default_description_display
      #logger.debug("OrgDetails:::: #{@orgDetails}")
      @OrganizationName = details[:OrganizationName]
      #logger.debug("OrgName::: #{@OrganizationName}")
      @OrgDescription = details[:OrganizationDescription]
      #logger.debug("OrgDesc::: #{@OrgDescription}")
      @siteHash = details[:siteHash]
      @poc = details[:poc]
      if details[:OrgSites] == [nil]
        @site = details[:OrgSites]
      else
        @site = details[:OrgSites].sort_by {|s| s['SelectSiteID'].to_i}
      end
      @geoscope = details[:geoscope]
      @program = details[:programs]
      # logger.debug("PROGRAM #{@program}")
      @PopulationDescription = details[:popDesc]
      @ProgramDescription = details[:progDesc]
      @ServiceAreaDescription = details[:servArea]
      @ProgramReferences = details[:progRef]

      @provider = params.has_key?(:provider_page) ? "master" : ""

      logger.debug("----------THE DETAILS OF THE ORG SITE IS : #{@site.count} /n ")
      @site.each do |s|
        logger.debug("*************** SITE Id is : #{s["SelectSiteID"]}")
      end


    end

    @pdfLinkSet = []



  end


  def catalogMangViewer

      table = params.has_key?(:provider_page) ? ENV["MASTER_TABLE_NAME"] : ENV["CATALOG_TABLE_NAME"]

      details = get_catalog_details(table)
      logger.debug("looking at the details, #{details}")
     
      get_details_for_catalog_mang_viewer(details)
      @pg_entry = false
      #@url = details[:url]
      ##logger.debug("WHAT IS THE URL  #{@url}")
      #@orgDetails = details[:OrgDetails]
      ## sets default org desc display if don't exists
      #set_default_description_display
      ##logger.debug("OrgDetails:::: #{@orgDetails}")
      #@OrganizationName = details[:OrganizationName]
      ##logger.debug("OrgName::: #{@OrganizationName}")
      #@OrgDescription = details[:OrganizationDescription]
      ##logger.debug("OrgDesc::: #{@OrgDescription}")
      #@siteHash = details[:siteHash]
      #@poc = details[:poc]
      #if details[:OrgSites] == [nil]
      #  @site = details[:OrgSites]
      #else
      #  @site = details[:OrgSites].sort_by {|s| s['SelectSiteID'].to_i}
      #end
      #@geoscope = details[:geoscope]
      #@program = details[:programs]
      #logger.debug("PROGRAM #{@program}")
      #@PopulationDescription = details[:popDesc]
      #@ProgramDescription = details[:progDesc]
      #@ServiceAreaDescription = details[:servArea]
      #@ProgramReferences = details[:progRef]

      #@provider = params.has_key?(:provider_page) ? "master" : ""

      ##@changed_fields = ScrapingRule.where(url: details[:url]).exists? ? ScrapingRule.find_by(url: details[:url]).changed_fields : ""
      #if ScrapingRule.where(url: details[:url]).exists?
      #  sr = ScrapingRule.find_by(url: details[:url])
      #  if sr.changed_fields.nil? || sr.changed_fields.empty?
      #    @changed_fields = ''
      #  else
      #    @changed_fields = sr.changed_fields
      #  end
      #else
      #  @changed_fields = ""
      #end


#this is for the PDF implementation 
#@pdfLinkSet = [] 
=begin   
    pdfSET = []
    @pdfLinkSet = []
      @program.each do |k,v|
            if k['PopulationDescription'].present?
                  k['PopulationDescription'].each do |x|
                    logger.debug("program we got #{x['Domain']}")
                        #if x['Domain'] != 'n/a'
                            #push each to array
                            pdfRequest = {}
                            pdfRequest[:dynamoURL] = @url
                            pdfRequest[:secondaryURL] = x['Domain']
                            logger.debug("what is #{pdfRequest}")
                            pdfSET.push(pdfRequest)
                        #end 
                  end 
            end 
      end 

      @site.each do |k,v|
          if k['SiteReference'].present?
              k['SiteReference'].each do |x|
                logger.debug("site we got #{x['Domain']}")
                        if x['Domain'] != 'n/a'
                            pdfRequest = {}
                            pdfRequest[:dynamoURL] = @url
                            pdfRequest[:secondaryURL] = x['Domain']
                            logger.debug("what is #{pdfRequest}")
                            pdfSET.push(pdfRequest)
                        end 
              end 
          end 
      end 


    #pdfSET.each do |thisPDF|
      #For Testing
      @pdfLinkSet = []
      pdfRequest = {}
      pdfRequest[:dynamoURL] = 'nwaccessfund.org'
      pdfRequest[:secondaryURL] = 'http://www.nwaccessfund.org/'

      #First Perform a GET of the URL, if status = none, CREATE
      uri = URI("http://localhost:3030/scrapePDF")
      header = {'Content-Type' => 'application/json'}
      http = Net::HTTP.new(uri.host, uri.port)
      puts "HOST IS : #{uri.host}, PORT IS: #{uri.port}, PATH IS : #{uri.path}"
      # http.use_ssl = true
      request = Net::HTTP::Get.new(uri.path, header)

      request.body = thisPDF.to_json
      # Send the request
      response = http.request(request)
      puts "response1 #{response.body}"
      myResponse = JSON.parse(response.body)

      if myResponse['status'] == 'none'
        uri = URI("http://localhost:3030/scrapePDF")
        header = {'Content-Type' => 'application/json'}
        http = Net::HTTP.new(uri.host, uri.port)
        puts "HOST IS : #{uri.host}, PORT IS: #{uri.port}, PATH IS : #{uri.path}"
        # http.use_ssl = true
        request = Net::HTTP::Post.new(uri.path, header)

        request.body = thisPDF.to_json
        # Send the request
        response = http.request(request)
        puts "response #{response.body}"
        puts JSON.parse(response.body)
        myPDF = JSON.parse(response.body)
        puts myPDF['pdf_s3_link']
      else
        logger.debug("In The Else")
          myResponse['pdf'].each do |x|
            puts x['pdf_s3_link']
            @pdfLinkSet.push(x['pdf_s3_link'])
          end 
      end 


    end #end set
=end


#this is for the PDF implementation 
=begin   
    pdfSET = []
    @pdfLinkSet = []
      @program.each do |k,v|
            if k['ProgramDescription'].present?
                  k['ProgramDescription'].each do |x|
                    logger.debug("program we got #{x['Domain']}")
                        #if x['Domain'] != 'n/a'
                            #push each to array
                            pdfRequest = {}
                            pdfRequest[:dynamoURL] = @url
                            pdfRequest[:secondaryURL] = x['Domain']
                            logger.debug("what is #{pdfRequest}")
                            pdfSET.push(pdfRequest)
                        #end 
                  end 
            end 
      end 

      @site.each do |k,v|
          if k['SiteReference'].present?
              k['SiteReference'].each do |x|
                logger.debug("site we got #{x['Domain']}")
                        if x['Domain'] != 'n/a'
                            pdfRequest = {}
                            pdfRequest[:dynamoURL] = @url
                            pdfRequest[:secondaryURL] = x['Domain']
                            logger.debug("what is #{pdfRequest}")
                            pdfSET.push(pdfRequest)
                        end 
              end 
          end 
      end 

#=end

  pdfSET.each do |thisPDF|
      #For Testing
      @pdfLinkSet = []
      #pdfRequest = {}
      #pdfRequest[:dynamoURL] = 'drinkblackeye.com'
      #pdfRequest[:secondaryURL] = 'https://www.drinkblackeye.com/menu-1'
      #First Perform a GET of the URL, if status = none, CREATE

      uri = URI("http://localhost:3030/scrapePDF")
      header = {'Content-Type' => 'application/json'}
      http = Net::HTTP.new(uri.host, uri.port)
      puts "HOST IS : #{uri.host}, PORT IS: #{uri.port}, PATH IS : #{uri.path}"
      # http.use_ssl = true
      request = Net::HTTP::Get.new(uri.path, header)

      request.body = thisPDF.to_json
      #request.body =  pdfRequest.to_json

      # Send the request
      response = http.request(request)
      puts "response1 #{response.body}"
      myResponse = JSON.parse(response.body)

      if myResponse['status'] == 'none'
        uri = URI("http://localhost:3030/scrapePDF")
        header = {'Content-Type' => 'application/json'}
        http = Net::HTTP.new(uri.host, uri.port)
        puts "HOST IS : #{uri.host}, PORT IS: #{uri.port}, PATH IS : #{uri.path}"
        # http.use_ssl = true
        request = Net::HTTP::Post.new(uri.path, header)

        request.body = thisPDF.to_json
        #request.body =  pdfRequest.to_json

        # Send the request
        response = http.request(request)
        puts "response #{response.body}"
        puts JSON.parse(response.body)
        myPDF = JSON.parse(response.body)

        puts "PARSED #{myPDF}"

        myPDF['pdf'].each do |x|
           @pdfLinkSet.push(x)
        end 

      else
        logger.debug("In The Else")
          myResponse['pdf'].each do |x|
            puts "here #{x}"
            @pdfLinkSet.push(x)
          end 
      end 

 end #end set loop

=end
  end 

  def get_details_for_catalog_mang_viewer(details)

    @url = details[:url]
    #logger.debug("WHAT IS THE URL  #{@url}")
    @orgDetails = details[:OrgDetails]
    # sets default org desc display if don't exists
    set_default_description_display
    #logger.debug("OrgDetails:::: #{@orgDetails}")
    @OrganizationName = details[:OrganizationName]
    #logger.debug("OrgName::: #{@OrganizationName}")
    @OrgDescription = details[:OrganizationDescription]
    #logger.debug("OrgDesc::: #{@OrgDescription}")
    @siteHash = details[:siteHash]
    @poc = details[:poc]
    if details[:OrgSites] == [nil]
      @site = details[:OrgSites]
    else
      @site = details[:OrgSites].sort_by {|s| s['SelectSiteID'].to_i}
    end
    @geoscope = details[:geoscope]
    @program = details[:programs]
    logger.debug("PROGRAM #{@program}")
    @PopulationDescription = details[:popDesc]
    @ProgramDescription = details[:progDesc]
    @ServiceAreaDescription = details[:servArea]
    @ProgramReferences = details[:progRef]
   
    @provider = params.has_key?(:provider_page) ? "master" : ""
 
    if ScrapingRule.where(url: details[:url]).exists?
      sr = ScrapingRule.find_by(url: details[:url])
      if sr.changed_fields.nil? || sr.changed_fields.empty?
        @changed_fields = ''
      else
        @changed_fields = sr.changed_fields
      end
    else
      @changed_fields = ""
    end

    @pdfLinkSet = []

  end

  def get_contact_management #modal

    # details = {organizationName: @organizationName, siteHash: @siteHash, poc: @poc, orgSites: @orgSites,
    #            programHash: @programHash, geoScope: @geoScope, programs: @programs }
    details = get_catalog_details(ENV["CATALOG_TABLE_NAME"]) 
    #@organizationName = details[:organizationName]
    #logger.debug("the orgName is : #{@organizationName}")
    #@siteHash = details[:siteHash]
    #@poc = details[:poc]
    #@orgSites = details[:orgSites]
    #@programHash = details[:programHash]
    #@geoScope = details[:geoScope]
    #@programs = details[:programs]
    @url = details[:url]
    logger.debug("WHAT IS THE URL  #{@url}")
    @orgDetails = details[:OrgDetails]
    logger.debug("OrgDetails:::: #{@orgDetails}")
    @OrganizationName = details[:OrganizationName]
    logger.debug("OrgName::: #{@OrganizationName}")
    @OrgDescription = details[:OrganizationDescription]
    logger.debug("OrgDesc::: #{@OrgDescription}")
    @siteHash = details[:siteHash]
    @poc = details[:poc]
    @site = details[:OrgSites]
    logger.debug("ORG SITES #{@site}")
    @geoscope = details[:geoscope]
    @program = details[:programs]
    logger.debug("PROGRAM #{@program}")
    @PopulationDescription = details[:popDesc]
    @ProgramDescription = details[:progDesc]
    @ServiceAreaDescription = details[:servArea]
    @ProgramReferences = details[:progRef]



    respond_to do |format|
      format.html
      format.js
    end
  end


  def duplicate_entry_details
    details = get_catalog_details(ENV["MASTER_TABLE_NAME"])
    # logger.debug("the detail are : #{details}")
    @organizationName = details[:organizationName]
    logger.debug("the orgName is : #{@organizationName}")
    @siteHash = details[:siteHash]
    @Addr1 = details[:addr1] 
    @SiteReference = details[:siteref] 

    @poc = details[:poc]
    @orgSites = details[:orgSites]
    @programHash = details[:programHash]
    @geoScope = details[:geoScope]
    @programs = details[:programs]
    @site = details[:sites]
    
    respond_to do |format|
      format.html
      format.js
    end
  end

  def master_provider_details

    details = get_catalog_details(ENV["MASTER_TABLE_NAME"])
    # logger.debug("the detail are : #{details}")
    @organizationName = details[:organizationName]
    logger.debug("the orgName is : #{@organizationName}")
    @siteHash = details[:siteHash]
    @poc = details[:poc]
    @orgSites = details[:orgSites]
    @programHash = details[:programHash]
    @geoScope = details[:geoScope]
    logger.debug("What is Geo #{@geoScope}")
    @programs = details[:programs]
    respond_to do |format|
      format.html
      format.js
    end
  end

  def get_catalog_details(table_name)
    dynamodb = Aws::DynamoDB::Client.new(region: "us-west-2")
    table_name = table_name

    parameters = {
        table_name: table_name,
        key: {
            # OrganizationName_Text: params["org_name"]
            url: params[:org_url]
        }
        # projection_expression: "url",
        # filter_expression: "url = test1.com"
    }

    @result = dynamodb.get_item(parameters)[:item]

    cat_details(@result)

      #######Update Selenium scrape test
      #uri = URI("http://localhost:3030/validateCatalog")
      #        header = {'Content-Type' => 'application/json'}
      #        http = Net::HTTP.new(uri.host, uri.port)
      #        puts "HOST IS : #{uri.host}, PORT IS: #{uri.port}, PATH IS : #{uri.path}"
      #        # http.use_ssl = true
      #        request = Net::HTTP::Post.new(uri.path, header)
      #
      #        request.body = @result.to_json
      #        # Send the request
      #        response = http.request(request)
      #        puts "response #{response.body}"
      #
      #######
  end

  def cat_details(catalog)
    catalog.each do |k,v|
      #logger.debug("NOW THE KEY MATTERS #{k} ::: V:: #{v}")
      case k.to_s
        when 'url'
          @url = v
          logger.debug("GETTING THE URL #{@url}")
        when 'Programs'
          @program = v
          #logger.debug("PROGRAM VALUE #{v}")

          v.each do |ary|
            ary.each do |key,value|
              if key.to_s == 'PopulationDescription'
                #      logger.debug("Value #{value}")
                @PopulationDescription = value

              elsif key.to_s == 'ProgramDescription'
                @ProgramDescription = value
                logger.debug("my mind is too busy:: #{@ProgramDescription}")

              elsif key.to_s == 'ServiceAreaDescription'
                @ServiceAreaDescription = value

              elsif key.to_s == 'ProgramReferences'
                @ProgramReferences = value
              end
            end
          end


        when 'OrgSites'
          #logger.debug("SITE SITE  #{v}")
          @site = v

          #v.each do |ary|
          v.each do |key,value|
            if key.to_s == 'Addr1'
              @Addr1 = v
            elsif key.to_s == 'SiteReference'
              @SiteReference = v
            elsif key.to_s == 'poc'
              @poc = v
            end
          end
        #end


        when 'OrganizationName'

          logger.debug("Org Name #{v}")
          @orgDetails = v

          v.each do |key,value|
            logger.debug("breakdown:: #{key} value:: #{value}")
            if key.to_s == 'OrganizationName'
              @OrganizationName = value
              logger.debug("Value #{@OrganizationName}")
            elsif key.to_s == 'OrgDescription'
              @OrgDescription = value
              #logger.debug("Value #{@OrgDescription}")
            end
          end

        when 'GeoScope'
          #logger.debug("Geo #{v}")
          @geoscope = v
      end

    end

    details = {
        url: @url,
        OrgDetails: @orgDetails,
        OrganizationName: @OrganizationName,
        OrganizationDescription: @OrgDescription,
        site: @site,
        addr1: @Addr1,
        siteref: @SiteReference,
        siteHash: @siteHash,
        poc: @poc,
        OrgSites: @site,
        geoscope: @geoscope,
        programs: @program,
        popDesc: @PopulationDescription,
        progDesc: @ProgramDescription,
        servArea: @ServiceAreaDescription,
        progRef: @ProgramReferences }

  end



  def plugin

    respond_to do |format|
      format.html
      format.js
    end

  end

  def download_plugin

    # s3 = Aws::S3::Resource.new(
    #     region: "us-east-1",
    #
    # )
    # zip_file= s3.bucket('chcplugin').object('AdWord.zip').get()
    #
    # logger.debug("the file output is : #{zip_file.body.inspect}")

    key = 'AdWord.zip'
    bucketName = "chcplugin"
    localPath = "/Users/harshavardhangandhari/RSI"
    # (1) Create S3 object
    s3 = Aws::S3::Resource.new(region: 'us-east-1')
    # (2) Create the source object
    sourceObj = s3.bucket(bucketName).object(key)
    # (3) Download the file
    sourceObj.get(response_target: localPath)
    puts "s3://#{bucketName}/#{key} has been downloaded to #{localPath}"
    # s3.bucket('chcplugin').object('AdWord.zip').send_file('/Users/harshavardhangandhari/RSI/')

    # bucket = s3.bucket('chcplugin')
    #
    # bucket.objects.limit(50).each do |item|
    #   puts "Name:  #{item.key}"
    #   puts "URL:   #{item.presigned_url(:get)}"
    # end

  end

  def define_parameters
    @parameter_for = params[:api_for]
    @client_application_id = params[:client_application_id]

    respond_to do |format|
      format.html
      format.js
    end
  end


  def external_api_setup
    if !params[:expected_paramas].blank?
      @hash_keys_array = []
      @chc_parameters = []
      eval(params[:expected_paramas]).each do |key, value|
        @hash_keys_array.push(key)
      end
      @client_application_id = params[:client_application_id]
      @api_name = params[:api_name]
      logger.debug("the hash is : #{eval(params[:expected_paramas])}")
      eas = ExternalApiSetup.new
      eas.client_application_id = @client_application_id
      eas.api_for = params[:api_for]
      eas.expected_parameters = eval(params[:expected_paramas])
      eas.save
      @external_api_id = eas.id.to_s

      logger.debug("the saved EAS is : #{eas.inspect}************** the keys are : #{@hash_keys_array}********external_api_id : #{@external_api_id}")
      parameter_exceptions = ["_id", "created_at", "updated_at"]

      model_array = [Patient, Referral, Task]

      model_array.each do |m|
        m.fields.keys.each do |p|
          if !parameter_exceptions.include?(p)
            @chc_parameters.push(p)
          end
        end
      end

      @chc_parameters.sort!
      logger.debug("the CHC parameters are : #{@chc_parameters}**************")

      respond_to do |format|
        format.html
        format.js
      end
    else
      logger.debug("in the else block of empty params")
      @show_error_messageg = true
      respond_to do |format|
        format.html
        format.js
      end
    end

  end

  def parameters_mapping
    logger.debug("IN the parameters mapping method************")
    external_parameters = params[:extermal_parameter]
    chc_parameters = params[:chc_parameter]
    external_api_id = params[:external_application_id]
    i = 0
    external_parameters.each do |ep|
      logger.debug("in the extermal parameters loop******************")
      mp = MappedParameter.new
      logger.debug("after creating new mappedparameters #{mp.inspect}******************")
      mp.external_api_setup_id = external_api_id
      mp.external_parameter = ep
      mp.chc_parameter = chc_parameters[i]
      logger.debug("after ADDING mappedparameters #{mp.inspect}******************")
      if mp.save
        logger.debug('the MP WAS SAVED***********')
      else
        logger.debug('NOT SAVEDDDDDDDDDDDd')
      end
      i+=1
    end

    respond_to do |format|
      format.html 
      format.js
    end

  end

  def get_patients
    user = current_user
    client_application_id = current_user.client_application.id.to_s
    @patients = Patient.where(client_application_id: client_application_id).order(last_name: :asc)
    @referrals = Referral.where(client_application_id: client_application_id).order(created_at: :desc).limit(3)

  end

  def send_task
    input = {task_id: params[:task_id], external_application_id: "5ab9145d58f01ad9374afd11" }
    uri = URI("http://localhost:3000/api/send_patient")
    header = {'Content-Type' => 'application/json'}
    http = Net::HTTP.new(uri.host, uri.port)
    puts "HOST IS : #{uri.host}, PORT IS: #{uri.port}, PATH IS : #{uri.path}"
    # http.use_ssl = true
    request = Net::HTTP::Post.new(uri.path, header)
    request.body = input.to_json

    # Send the request
    response = http.request(request)
    puts "response #{response.body}"
    puts JSON.parse(response.body)
  end

  def check_duplicate_entries
    logger.debug("IN THE DUPLICATE METHOD*************")
    # catalog = params[:catalog]
    dynamodb = Aws::DynamoDB::Client.new(region: "us-west-2")
    # table_name = 'master_provider'
    table_name = ENV["MASTER_TABLE_NAME"]
    org_url = params[:org_url]
    params = {
        table_name: table_name,
        key_condition_expression: " #ur = :u",
        expression_attribute_names: {
            "#ur" => "url"
        },
        expression_attribute_values: {
            ":u" => org_url
        }
    }
    begin
      result = dynamodb.query(params)
      # puts "Query succeeded."
      catalog = helpers.get_catalog(org_url)
      logger.debug("the RESULT IS : #{result[:items]}")
      if !result[:items].empty?
        items = result[:items]
        logger.debug("RESULT IS NOT EMPTY!!!!!!!!!!!*****************")
        duplicates = check_for_sites(catalog, items)
      else
        logger.debug("THE RESULT IS EMPTY!!!!!!!!!!*****************")
        duplicates = []
      end
    rescue  Aws::DynamoDB::Errors::ServiceError => error
      puts "Unable to query table:"
      puts "#{error.message}"
    end
      @duplicates = duplicates
  end

  def check_for_sites(catalog, items)

    catlog_zip = []
    item_zip = []
    duplicate_array = []
    catalog["orgSites"].each do|site|
      zip = site["Adrzip"]
      catlog_zip.push(zip)
    end

    items.each do |i|

      i["orgSites"].each do|site|
        zip = site["Adrzip"]
        item_zip.push(zip)
      end
      if item_zip == catlog_zip
        duplicate_array.push(i)
      end
    end
    logger.debug("**************THE DUPLICATE ARRAY IS : #{duplicate_array}")
    duplicate_array

  end

  def send_for_approval
    logger.debug("YOU STILL KNOW RAILS")
    logger.debug("Collecting info #{params['orgName']} &&&URL #{params['url']}")
    dynamodb1 = Aws::DynamoDB::Client.new(region: "us-west-2")
    parameters = {
        # table_name: 'contact_management',
        table_name: ENV["CATALOG_TABLE_NAME"],
        key: {
            url: params["url"]
        },
        update_expression: "set #st = :s ",
        expression_attribute_values: {
            ":s" => 'Pending'
        },
        expression_attribute_names: { 
            "#st" => "status"
        },
        return_values: "UPDATED_NEW"
    }

        begin
          dynamodb1.update_item(parameters)
          # render :json => {status: :ok, message: "Catalog Updated" }
        rescue  Aws::DynamoDB::Errors::ServiceError => error
          render :json => {message: error  }
        end

    # dynamodb = Aws::DynamoDB::Client.new(region: "us-west-2")
    #
    # table_name = 'contact_management'
    # params = {
    #     table_name: table_name,
    #     # projection_expression: "url",
    #     # filter_expression: "url = test1.com"
    # }
    #
    # @result = dynamodb.scan(params)[:items] #.sort_by!{|k| k["created_at"]}.reverse!
    @result = helpers.catalog_table_content

    @pending_results = @result.select{|p| p["status"] == "Pending"}
    @sr_urls = ScrapingRule.all.pluck(:url)
    logger.debug("the sr ursls are  : ************************ #{@sr_urls}")

    logger.debug("the RESULT OF THE SCAN IS : ************************")

    #@masterStatus = @client_application.master_application_status

    # user = current_user
    # @client_application = current_user.client_application
    # @masterStatus = @client_application.master_application_status
  end

  def approve_catalog

  #logger.debug("Collecting info #{params['orgName']} &&&URL #{params['url']} &&&& #{params['pocEmail']}")
  dynamodb1 = Aws::DynamoDB::Client.new(region: "us-west-2")
  parameters = {
      # table_name: 'contact_management',
      table_name: ENV["CATALOG_TABLE_NAME"],
      key: {
          url: params["url"]
      },
      update_expression: "set #st = :s ",
      expression_attribute_values: {
          ":s" => 'Approved'
      },
      expression_attribute_names: { 
          "#st" => "status"
      },
      return_values: "UPDATED_NEW" 
  }


      begin
        dynamodb1.update_item(parameters)
        insert_in_master_provider(params["url"], params['pocEmail'])
        helpers.creating_scraping_rule(params["url"])
        render :json => {status: :ok, message: "Catalog Updated" }
      rescue  Aws::DynamoDB::Errors::ServiceError => error
        render :json => {message: error  }
      end 
  end

  def insert_in_master_provider(url, pocEMAIL)


    dynamodb = Aws::DynamoDB::Client.new(region: "us-west-2")
    table_name = ENV["CATALOG_TABLE_NAME"]
    parameters = {
        table_name: table_name,
        key: {
            # OrganizationName_Text: params["org_name"]
            url: url
        }
        # projection_expression: "url",
        # filter_expression: "url = test1.com"
    }

    result = dynamodb.get_item(parameters)[:item]
    
    if pocEMAIL != 'noemail@poc.com' || pocEMAIL != ''
      result['poc_emailed'] = true
      PocMailer.poc_welcome(pocEMAIL).deliver
    else 
      result['poc_emailed'] = false
    end 

    logger.debug("******************insert_in_master_provider #{result}")

    table_name1 = ENV["MASTER_TABLE_NAME"]

    params1 = {
        table_name: table_name1,
        item: result
    }

    begin
      dynamodb.put_item(params1)
      helpers.create_pg_entry(result)
      # render :json => { status: :ok, message: "Entry created successfully"  }
    rescue  Aws::DynamoDB::Errors::ServiceError => error
      render :json => {message: error  }
    end


  end



  def reject_catalog   
    logger.debug("YOU STILL KNOW RAILS2 #{[params]}")
    logger.debug("Collecting info #{params['orgName']} &&&URL #{params['url']}")
    dynamodb1 = Aws::DynamoDB::Client.new(region: "us-west-2")
    parameters = {
        table_name: ENV["CATALOG_TABLE_NAME"],
        key: {
            url: params["url"]
        },
        update_expression: "set #st = :s ",
        expression_attribute_values: {
            ":s" => 'Rejected'
        },
        expression_attribute_names: { 
            "#st" => "status"
        },
        return_values: "UPDATED_NEW"
    }

        begin
          dynamodb1.update_item(parameters)
          # render :json => {status: :ok, message: "Catalog Updated" }
        rescue  Aws::DynamoDB::Errors::ServiceError => error
          render :json => {message: error  }
        end

    @result = helpers.catalog_table_content

  end 
  def delete_catalog
    logger.debug("YOU STILL KNOW RAILS2 #{params['url']}")
    dynamodb1 = Aws::DynamoDB::Client.new(region: "us-west-2")
    parameters = {
        table_name: ENV["CATALOG_TABLE_NAME"],
        key: {
            url: params["url"]
        }
      }

    begin
      dynamodb1.delete_item(parameters)
      puts 'Deleted this rule'
    rescue  Aws::DynamoDB::Errors::ServiceError => error
      puts 'Unable to delete movie:'
      puts error.message
    end
    #find by id and delete 
  end

  def agreement_management

    @ceas = AgreementTemplate.where(agreement_type: "CE-A")
    @cebs = AgreementTemplate.where(agreement_type: "CE-B")
    @ba1s = AgreementTemplate.where(agreement_type: "BA-1")
    @babs = AgreementTemplate.where(agreement_type: "BA-B")
    @cbos = AgreementTemplate.where(agreement_type: "CBO")

  end

  def add_agreement_template
    @agreement_template = AgreementTemplate.new
  end

  def create_agreement_template #DOUBLE CHECK             
    logger.debug("you are in the creeate cea METHOD************** #{params.inspect}")
    agreement_template = AgreementTemplate.new
    agreement_template.file_name = params["agreement_template"]["file_name"]
    agreement_template.agreement_doc = params["agreement_template"]["agreement_doc"]
    agreement_template.agreement_type = params["agreement_template"]["agreement_type"]
    # Valid Till Agreement
    agreement_template.client_agreement_valid_til = params["agreement_template"]["client_agreement_valid_til"]
    agreement_template.agreement_expiration_date = params["agreement_template"]["agreement_expiration_date"]
    #Valid For Agreement
    agreement_template.client_agreement_valid_for = params["agreement_template"]["client_agreement_valid_for"]
    agreement_template.valid_for_integer = params["agreement_template"]["valid_for_integer"]
    agreement_template.valid_for_interval = params["agreement_template"]["valid_for_interval"]

    agreement_template.save

    redirect_to agreement_management_path
  end

  def change_status_of_agreement_template
    logger.debug("IN THE change_status_of_agreement_template--------------- the id is #{params[:id]}")
    agt = AgreementTemplate.find(params[:id])
    agt.active = true
    agt.save

    @agt_type = agt.agreement_type

    AgreementTemplate.where(agreement_type: @agt_type ).each do |at|
      if at.id.to_s != params[:id]
        at.active = false
        at.save
      end
    end

    case @agt_type
      when "CE-A"
        @agreement = AgreementTemplate.where(agreement_type: "CE-A")
      when "CE-B"
        @agreement = AgreementTemplate.where(agreement_type: "CE-B")
      when "BA-1"
        @agreement = AgreementTemplate.where(agreement_type: "BA-1")
      when "BA-B"
        @agreement = AgreementTemplate.where(agreement_type: "BA-B")
    end
    # @ceas = AgreementTemplate.where(agreement_type: "CE-A")
    # @cebs = AgreementTemplate.where(agreement_type: "CE-B")
    # @ba1s = AgreementTemplate.where(agreement_type: "BA-1")
    # @babs = AgreementTemplate.where(agreement_type: "BA-B")


  end

  def pending_agreements 

    @applications = ClientApplication.where(agreement_counter_sign: "Pending")
    @all_agreements = ClientApplication.where(:client_agreement.ne => nil)

  end

  def counter_sign_popup
    @customer = ClientApplication.find(params[:id])

  end

  def upload_countersign_doc
    customer = ClientApplication.find(params[:client_application][:id])
    customer.client_agreement = params[:client_application][:client_agreement]
    customer.agreement_counter_sign = "Done"
    customer.agreement_signed = true
    customer.client_agreement_sign_date = Date.today
    customer.save

    redirect_to pending_agreements_path
  end

  def reject_agreement_template
    customer = ClientApplication.find(params[:cus_id])
    customer.agreement_counter_sign = "Rejected"
    customer.reason_for_agreement_reject = params[:reason_for_reject]
    customer.save
    redirect_to pending_agreements_path
  end

  def question_sequence
    @questions = Question.all

  end

  def update_sequence
    question = Question.find(params[:question])
    if params[:change_param] == "pre_que"
      logger.debug("IN THE PRE QUE********************")
      question.pq = params[:changed_value]
    elsif params[:change_param] == "next_que_yes"
      logger.debug("IN THE NEXT QUE YES ********************")
      question.nqy = params[:changed_value]
    elsif params[:change_param] == "next_que_no"
      logger.debug("IN THE NEXT QUE NO ********************")
      question.nqn = params[:changed_value]
    end

    question.save

  end

  def sample_page

  end

  def fhir_response

    url = URI("http://64.227.10.117:8080/baseDstu3/Patient?_pretty=true")
    header = {'Content-Type' => 'application/json'}
    http = Net::HTTP.new(url.host, url.port)
    # http.use_ssl = true
    request = Net::HTTP::Get.new(url.path, header)
    # request.body = input.to_json
    response = http.request(request)
    # logger.debug("RESPONSE #{response.body}")
    # result = JSON.parse(response.body["entry"])
    result = JSON.parse(response.body)["entry"]

    result.each do |r|
      # logger.debug(r["resource"]["name"][0]["family"])
      # logger.debug(r["resource"]["name"][0]["given"][0])
      # logger.debug(r["resource"]["gender"])

      input= {
          "last_name": r["resource"]["name"][0]["family"],
          "first_name": r["resource"]["name"][0]["given"][0],
          "gender": r["resource"]["gender"],
          "dob": "05-29-1980",
          "id": r["resource"]["id"]
      }

      logger.debug("the input is : #{input}")
      kafka = Kafka.new(["167.172.150.43:9092"], client_id: "my-application")
      # kafka = Kafka.new(["localhost:9092"], client_id: "my-application")
      producer = kafka.producer
      producer.produce(input.to_json,topic: "CHC-Dentistlink-receive-patient")
      # producer.produce(input.to_json,topic: "my-topic")
      producer.deliver_messages

    end

  end

  def pg_filter

  end

  def filtered_list


    input = {"tag": params[:tag]}
    uri = URI("http://pg.commonhealthcore.org/filter_service_tag")

    header = {'Content-Type' => 'application/json'}

    http = Net::HTTP.new(uri.host, uri.port)
    # http.use_ssl = true
    request = Net::HTTP::Post.new(uri.path, header)
    request.body = input.to_json

    # logger.debug(" the request body is : #{request}")
    response = http.request(request)
    #puts "*******************response #{response.body} "
    #logger.debug("******* the response is ---------#{JSON.parse(response.body}")
    result = JSON.parse(response.body)
    logger.debug("--------in the filtered_list #{result}")
    @programs = result["result"]

  end

  def see_pg_entry

    input = {"domain": params[:domain]}
    uri = URI("http://pg.commonhealthcore.org/get_entry_by_domain")

    header = {'Content-Type' => 'application/json'}

    http = Net::HTTP.new(uri.host, uri.port)
    # http.use_ssl = true
    request = Net::HTTP::Post.new(uri.path, header)
    request.body = input.to_json

    # logger.debug(" the request body is : #{request}")
    response = http.request(request)
    # puts "response {response.body} "
    logger.debug("********** the response of get entry by domain is  #{JSON.parse(response.body)}")
    result = JSON.parse(response.body)

    details = cat_details(result["catalog"])
    get_details_for_catalog_mang_viewer(details)
    @pg_entry = true

    render :template => 'client_applications/catalogMangViewer'

  end


  private
  # Use callbacks to share common setup or constraints between actions.
  def set_client_application
    @client_application = ClientApplication.find(params[:id])
  end

  # Never trust parameters from the scary internet, only allow the white list through.
  def client_application_params
    # params.fetch(:client_application, {})
    params.require(:client_application).permit(:name, :application_url,:service_provider_url, :custom_agreement, :custom_agreement_comment, :agreement_expiration_date, :valid_for_integer, :valid_for_interval, :client_agreement_valid_til, :client_agreement_valid_for, :client_agreement_expiration, :client_agreement_sign_date, :accept_referrals, :client_speciality, :client_agreement, :agreement_type, :logo, :theme ,#users_attributes: [:name, :email, :_destroy],

    notification_rules_attributes: [:appointment_status, :time_difference,:subject, :body])
  end
end
