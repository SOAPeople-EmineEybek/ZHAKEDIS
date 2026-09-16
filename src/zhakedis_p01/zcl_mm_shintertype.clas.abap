CLASS zcl_mm_shintertype DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider .
  PROTECTED SECTION.
  PRIVATE SECTION.
    METHODS handle_paging
      IMPORTING
        i_io_request TYPE REF TO if_rap_query_request.
ENDCLASS.



CLASS ZCL_MM_SHINTERTYPE IMPLEMENTATION.


  METHOD handle_paging.
    DATA(offset) = i_io_request->get_paging(  )->get_offset( ).
    DATA(page_size) = i_io_request->get_paging(  )->get_page_size(  ).
    DATA(max_rows) = COND #( WHEN page_size = if_rap_query_paging=>page_size_unlimited THEN 0 ELSE page_size ).
  ENDMETHOD.


  METHOD if_rap_query_provider~select.

    DATA lt_list TYPE STANDARD TABLE OF zmmr_shintertype.
    FIELD-SYMBOLS: <fs_mr_values> TYPE STANDARD TABLE,
                   <fs_mr_value>  TYPE any.

    DATA(lv_entity) = io_request->get_entity_id(  ).
    DATA(filters) = io_request->get_filter(  ).
    DATA(params) = io_request->get_parameters(  ).

    IF io_request->is_data_requested(  ).
      DATA(asd) = io_request->get_requested_elements(  ).
    ENDIF.

    IF io_request->is_data_requested(  ).
      handle_paging( io_request ).

      TRY.
          DATA(ranges) = filters->get_as_ranges(  ).
        CATCH cx_rap_query_filter_no_range."#EC NO_HANDLER
        ##NO_HANDLER
          "handle exception
      ENDTRY.

      IF line_exists( ranges[ name = 'INTERRUPTIONTYPE' ] ).
        DATA(lrt_INTERRUPTIONTYPE) = VALUE #( ranges[ name = 'INTERRUPTIONTYPE' ]-range ).
      ENDIF.



      DATA(lv_offset) = io_request->get_paging(  )->get_offset( ).
      DATA(lv_rowcount) = io_request->get_paging(  )->get_page_size(  ).


      SELECT *
        FROM zmmt_inter_type
*        WHERE ( INTERRUPTIONTYPE IN @lrt_INTERRUPTIONTYPE )
              ORDER BY INTERRUPTIONTYPE
        INTO CORRESPONDING FIELDS OF TABLE @lt_list
        OFFSET @lv_offset
        UP TO @lv_rowcount ROWS."#EC CI_NOWHERE


    ENDIF.
    io_response->set_data( lt_list ).
    IF io_request->is_total_numb_of_rec_requested(  ).
      io_response->set_total_number_of_records( lines( lt_list ) ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
