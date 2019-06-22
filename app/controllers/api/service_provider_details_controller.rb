module Api
  class ServiceProviderDetailsController < ActionController::Base
    include UsersHelper
    before_action :authenticate_user_from_token, except: [:scrappy_doo_response, :authenticate_user_email, :update_catalogue_site_by_id,
                                                          :get_catalogue_site_by_id,:catalogue_site_list,:get_catalogue_program_by_id,
    :catalogue_program_list]
    load_and_authorize_resource class: :api, except: [:scrappy_doo_response, :authenticate_user_email,:update_catalogue_site_by_id,
    :get_catalogue_site_by_id,:catalogue_site_list,:get_catalogue_program_by_id,:catalogue_program_list]

    def create_provider
      client_application = User.find_by(email: params[:email]).client_application_id.to_s
      logger.debug("client application: #{client_application}")
      sp = ServiceProviderDetail.new
      sp.client_application_id = client_application
      sp.service_provider_name = params[:service_provider_name]

      sp.service_provider_api = params[:service_provider_api] if params[:service_provider_api]
      sp.data_storage_type = params[:data_storage_type] if params[:data_storage_type]
      sp.provider_type = params[:provider_type] if params[:provider_type]
      sp.share = params[:share] if params[:share]
      sp.provider_data_file = params[:provider_data_file]
      sp.filtering_fields = params[:filtering_fields].to_unsafe_h
      logger.debug("SERVICE PROVIDER IS : #{sp.inspect}----------------------------")
      if sp.save
        logger.debug("SERVICE PROVIDER IS SAVED***************************")
        render :json=> {status: :ok, :message=> "Provide Details Created successfully"  }
      end


    end

    def edit_provider_details

      spd = ServiceProviderDetail.find(params[:spd_id])
      spd.service_provider_name = params[:service_provider_name]

      spd.service_provider_api = params[:service_provider_api] if params[:service_provider_api]
      spd.data_storage_type = params[:data_storage_type] if params[:data_storage_type]
      spd.provider_type = params[:provider_type] if params[:provider_type]
      spd.share = params[:share] if params[:share]
      spd.filtering_fields = params[:filtering_fields].to_unsafe_h

      if spd.save
        render :json=> {status: :ok, :message=> "Provide Details updated successfully"  }
      end

    end

    def scrappy_doo_response

      logger.debug("the parameters are: #{params.inspect}")
      sr = ScrapingRule.find(params[:rule_id])
      rules_to_change = params[:ruleToChange]
      rules_to_change.each do |r_change|
        if r_change == "organizationName"
          sr.organizationName_changeeee = true
        elsif r_change == "organizationDescription"
          sr.organizationDescription_changeeee = true
        end
      end
      sr.save
      #{"ruleToChange"=>["OrganizationName", "OrganizationDescription"], "rule_id"=>" 5c7418b158f01a070996c531", "service_provider_detail"=>{}}

    end

    def contact_management_details_for_plugin
      dynamodb = Aws::DynamoDB::Client.new(region: "us-west-2")
      table_name = 'contact_management'

      parameters = {
          table_name: table_name,
          key: {
              # OrganizationName_Text: params["org_name"]
              url: params["org_url"]
          }
          # projection_expression: "url",
          # filter_expression: "url = test1.com"
      }

      result = dynamodb.get_item(parameters)[:item]
      if result.nil?
        result = {}
      end

      # logger.debug("the Result of the get entry is : #{result}")
      render :json => {status: :ok, result: result }
    end


    def get_catalogue_site_by_id

      dynamodb = Aws::DynamoDB::Client.new(region: "us-west-2")
      table_name = 'contact_management'

      parameters = {
          table_name: table_name,
          key: {
              # OrganizationName_Text: params["org_name"]
              # url: params["org_url"]
              url: params["url"]
          }
      }

      result = dynamodb.get_item(parameters)[:item]["orgSites"].select{|item| item["sideID"] == params["sideID"]}
      # result = dynamodb.get_item(parameters)[:item]["OrgSites"].collect{|item| item["ID"]}


      # logger.debug("the Result of the get entry is : #{result}")
      render :json => {status: :ok, result: result }

    end

    def update_catalogue_site_by_id
      #
      # dynamodb = Aws::DynamoDB::Client.new(region: "us-west-2")
      # table_name = 'contact_management'
      #
      # parameters = {
      #     table_name: table_name,
      #     key: {
      #         # OrganizationName_Text: params["org_name"]
      #         # url: params["org_url"]
      #         url: "test3.com"
      #     }
      #     # projection_expression: "url",
      #     # filter_expression: "url = test1.com"
      # }
      #
      # result = dynamodb.get_item(parameters)[:item]["OrgSites"]
      # # result = dynamodb.get_item(parameters)[:item]["OrgSites"].collect{|item| item["ID"]}
      #
      # result.delete_if {|h| h["ID"] == "1"}
      # new_hash = params[:NewHash]
      #
      # logger.debug("the new hash IS : #{new_hash}")
      #
      # result << new_hash
      #
      # new_result = result
      #
      # logger.debug("the new result is : #{new_result}")
      #
      # parameters = {
      #     table_name: table_name,
      #     key: {
      #         # OrganizationName_Text: params["org_name"]
      #         # url: params["org_url"]
      #         url: "test3.com"
      #     },
      #     update_expression: "set info.OrgSites = :r ",
      #     expression_attribute_values: {
      #     ":r" => new_result
      # },
      #     return_values: "UPDATED_NEW"
      # }
      #
      # dynamodb.update_item(parameters)
      #
      # # logger.debug("the Result of the get entry is : #{result}")
      # render :json => {status: :ok, result: result }

    end

    def catalogue_site_list
      dynamodb = Aws::DynamoDB::Client.new(region: "us-west-2")
      table_name = 'contact_management'

      parameters = {
          table_name: table_name,
          key: {
              # OrganizationName_Text: params["org_name"]
              url: params["url"]
              # url: "test1.com"
          }
          # projection_expression: "url",
          # filter_expression: "url = test1.com"
      }


      result = dynamodb.get_item(parameters)[:item]["orgSites"].collect{|item| [item["siteID"],item["locationName_Text"]]}


      # logger.debug("the Result of the get entry is : #{result}")
      render :json => {status: :ok, result: result }
    end


    def get_catalogue_program_by_id

      dynamodb = Aws::DynamoDB::Client.new(region: "us-west-2")
      table_name = 'contact_management'

      parameters = {
          table_name: table_name,
          key: {
              # OrganizationName_Text: params["org_name"]
              # url: params["org_url"]
              url: params["url"]
          }
      }

      result = dynamodb.get_item(parameters)[:item]["programs"].select{|item| item["programID"] == params["programID"]}
      # result = dynamodb.get_item(parameters)[:item]["OrgSites"].collect{|item| item["ID"]}


      # logger.debug("the Result of the get entry is : #{result}")
      render :json => {status: :ok, result: result }

    end

    def update_catalogue_program_by_id


    end

    def catalogue_program_list

      dynamodb = Aws::DynamoDB::Client.new(region: "us-west-2")
      table_name = 'contact_management'

      parameters = {
          table_name: table_name,
          key: {
              # OrganizationName_Text: params["org_name"]
              url: params["url"]
              # url: "test1.com"
          }
          # projection_expression: "url",
          # filter_expression: "url = test1.com"
      }


      result = dynamodb.get_item(parameters)[:item]["programs"].collect{|item| item["programID"]}


      # logger.debug("the Result of the get entry is : #{result}")
      render :json => {status: :ok, result: result }
    end



    def authenticate_user_email
      user = User.where(email: params[:email])
      logger.debug("the email being authenticated is : #{user.inspect}")

      if !user.empty?
        render :json=> {status: :ok, :message=> "Valid User"  }
      else
        render :json=> {status: :unauthorized, :message=> "Invalid User" }
      end

    end

    def filter_provider

      # service_provider_id = params[:provider_id]
      #
      # provider = ServiceProviderDetail.find(service_provider_id)
      #
      # logger.debug("the provider is: #{provider.inspect}")
      # database_storage = provider.data_storage_type
      # if database_storage == "External"
      #
      #
      # elsif database_storage == "Internal"
      #
      # end

      # https://aokx9crg6l.execute-api.us-west-2.amazonaws.com/prod/Hello?
      # input = {"input": "{\"treatment\": {type: \"Input\", value: [\"surgery\", \"cleaning\"]}}"}
      # a = ["surgery", "cleaning", "Pain"]

      a = 'Apple'
      b = 'Not Accepting'
      c = "99203"
      # input = {"Name": {type: "Input", value: a }, "Adult": {type: "Dropdown", value: b}}
      # input = {"Billing_Zip/Postal_Code": {type: "zipcode", value: c }}
      zip_adult = {"Billing_Zip/Postal_Code": {type: "zipcode", value: c },  "Adult": {type: "Dropdown", value: b} }
      name_adult = {"Name": {type: "Input", value: a }, "Adult": {type: "Dropdown", value: b}}

      input = params[:input]

      uri = URI("https://aokx9crg6l.execute-api.us-west-2.amazonaws.com/post_hash")
      header = {'Content-Type' => 'text/json'}

      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      request = Net::HTTP::Post.new(uri.path, header)
      request.body = input.to_json

      logger.debug(" the request body is : #{request}")
      response = http.request(request)
      # puts "response #{response.body}"
      puts JSON.parse(response.body)
      render :json=> {status: :ok, :provider_data=> JSON.parse(response.body) }

    end

  end
end
