# Place all the behaviors and hooks related to the matching controller here.
# All this logic will automatically be available in application.js.
# You can use CoffeeScript in this file: http://coffeescript.org/
jQuery ($) ->
  console.log("Client Application Coffee****")
  $(document).on("click", ".requested_application", ->
    id = $(this).attr("id")
    console.log("the id of the invite is ", id)
    $.post "/send_application_invitation",
      id: id
    return
  )

  $('#notification_rules').DataTable();

  $('#user_list').DataTable({ responsive: true });

  $('#client_application').DataTable( );

  $('#contact_management_table').DataTable( "order": []);

  $(document).on("click", ".external_api_setup", ->
#    text = $("#send_patient").val()
    client_id = $("#client_application_id").val()
    api_array = []
    $(".external_api_text_field").each ->
      id=  $(this).attr('id')
      text = $(this).val()
      h = {id: id, text: text }
      if text.length != 0
        api_array.push(h)
      console.log("the id is : ", id, 'the text is :', text)

    console.log("the array from js is :", api_array, "Client ID is : ", client_id  )
    $.post "/after_signup_external/api_setup",
      api_array: api_array,
      client_id: client_id
    return
  )