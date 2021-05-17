module ScrapingRulesHelper

  def creating_scraping_rule(url)
    dynamodb = Aws::DynamoDB::Client.new(region: "us-west-2")
    # table_name = 'contact_management'
    table_name = ENV["MASTER_TABLE_NAME"]

    parameters = {
        table_name: table_name,
        key: {
            url: url
        }
        # projection_expression: "url",
        # filter_expression: "url = test1.com"
    }

    result = dynamodb.get_item(parameters)[:item]

    logger.debug("***********************************************the Result of the get entry is : #{result}")
    programDetails_array = []
    siteDetails_array = []
    result.each do |key, value|
      logger.debug("************************the key is : #{key}, and the value is : #{value.class}")
      if key.include?("Programs")
        programDetails_array.push("#{key}"=> value)
      elsif key.include?("OrgSites")
        siteDetails_array.push(value)
      end
    end

    logger.debug("*************************the number of programDetails are : #{programDetails_array}")
    logger.debug("*************************the number of siteDetails are : #{siteDetails_array}")
    # logger.debug("!!!!!!!!!!!!!!!!!!!!!!!!!the OrgDescription is : #{result["OrganizationName"]["OrgDescription"][0].class}")


    # @row = params[:row_id]
    sr = ScrapingRule.where(url: result["url"]).empty? ? ScrapingRule.new : ScrapingRule.find_by(url: result["url"])

    # sr = ScrapingRule.new
    # sr.url = params[:url]
    # sr.organizationName_Text = result["OrganizationName_Text"]
    # sr.organizationName_xpath = result["OrganizationName_xpath"]
    # sr.organizationName_URL = result["OrganizationName_URL"]
    # sr.organizationDescription_Text = result["OrganizationDescription_Text"]
    # sr.organizationDescription_URL = result["OrganizationDescription_URL"]
    # sr.organizationDescription_xpath = result["OrganizationDescription_xpath"]
    sr.url = result["url"]
    sr.organizationName = result["OrganizationName"]["OrganizationName"][0] if result["OrganizationName"]["OrganizationName"]
   # sr.organizationDescription = result["OrganizationName"]["OrgDescription"][0] if result["OrganizationName"]["OrgDescription"]
    sr.organizationDescription = result["OrganizationName"]["OrgDescription"] ? result["OrganizationName"]["OrgDescription"][0] : {}
    sr.geoScope = result["GeoScope"] if result["GeoScope"]
    sr.programDetails = programDetails_array
    sr.siteDetails = siteDetails_array.flatten
    logger.debug("*************** The SR being saved is #{sr.inspect}")
    #
    sr.save
  end

end
