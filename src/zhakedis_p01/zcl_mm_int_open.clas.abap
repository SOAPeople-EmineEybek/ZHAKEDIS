CLASS zcl_mm_int_open DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider .
  PROTECTED SECTION.
  PRIVATE SECTION.
    METHODS handle_paging
      IMPORTING
        i_io_request TYPE REF TO if_rap_query_request.
ENDCLASS.



CLASS ZCL_MM_INT_OPEN IMPLEMENTATION.


 METHOD handle_paging.
    DATA(offset) = i_io_request->get_paging(  )->get_offset( ).
    DATA(page_size) = i_io_request->get_paging(  )->get_page_size(  ).
    DATA(max_rows) = COND #( WHEN page_size = if_rap_query_paging=>page_size_unlimited THEN 0 ELSE page_size ).
  ENDMETHOD.


  METHOD if_rap_query_provider~select.


    DATA: ls_request  TYPE  zmms_int_close_imp,

          lt_return   TYPE TABLE OF zmmr_int_close,
          ls_response TYPE  zmms_int_close_exp,
          lt_response TYPE TABLE OF  zmms_int_close_exp.

    DATA(lv_date) = cl_abap_context_info=>get_system_date( ).
    DATA: lv_sdate TYPE d.
    handle_paging( io_request ).
    DATA(filters) = io_request->get_filter(  ).
    IF io_request->is_data_requested(  ).
      TRY.
          DATA(ranges) = filters->get_as_ranges(  ).
        CATCH cx_rap_query_filter_no_range."#EC NO_HANDLER
        ##NO_HANDLER
      ENDTRY.

      IF line_exists( ranges[ name = 'FILTER' ] ).
        DATA(lr_filter) = VALUE #( ranges[ name = 'FILTER' ]-range ).
        READ TABLE lr_filter INTO DATA(ls_filter) INDEX 1.
        IF ls_filter-low IS NOT INITIAL.
          /ui2/cl_json=>deserialize( EXPORTING json = ls_filter-low pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = ls_request ).
        ENDIF.
      ENDIF.
    ENDIF.

    IF ls_request-serviceentrysheet IS NOT INITIAL.
      zcl_mm_int_gen=>get_instance(
            IMPORTING
              r_instance    = DATA(ro_instance)
                    ).
      ro_instance->open_int(
        EXPORTING
          it_serviceentrysheet = ls_request-serviceentrysheet
        RECEIVING
          er_mess = DATA(lv_mess)
      ).
      ls_response-message =  lv_mess.

    ELSE.
      ls_response-message = 'Açma işlemi başarısız'.
    ENDIF.


    DATA(lv_offset) = io_request->get_paging(  )->get_offset( ).
    DATA(lv_rowcount) = io_request->get_paging(  )->get_page_size(  ).


    APPEND  ls_response TO  lt_response  .
    /ui2/cl_json=>serialize( EXPORTING data = lt_response pretty_name = /ui2/cl_json=>pretty_mode-camel_case RECEIVING r_json = DATA(lv_res_json) ).
    APPEND INITIAL LINE TO lt_return ASSIGNING FIELD-SYMBOL(<fs_return>).
    <fs_return>-treetable = lv_res_json.
    <fs_return>-filter    = space.
    "RETURN
    io_response->set_data( lt_return ).
    IF io_request->is_total_numb_of_rec_requested(  ).
      io_response->set_total_number_of_records( lines( lt_return ) ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
