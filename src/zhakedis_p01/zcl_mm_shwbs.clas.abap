CLASS zcl_mm_shwbs DEFINITION
  PUBLIC FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_rap_query_provider .
  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS ZCL_MM_SHWBS IMPLEMENTATION.


  METHOD if_rap_query_provider~select.

    DATA lt_list TYPE STANDARD TABLE OF zmmr_shwbs.

    IF io_request->is_data_requested( ).

      DATA(lv_offset) = io_request->get_paging( )->get_offset( ).
      DATA(lv_rowcount) = io_request->get_paging( )->get_page_size( ).

      SELECT projectelement AS wbselement, "#EC CI_NOWHERE
             projectelementdescription AS wbsdescription
        FROM i_enterpriseprojectelement
        ORDER BY projectelement
        INTO CORRESPONDING FIELDS OF TABLE @lt_list
        OFFSET @lv_offset
        UP TO @lv_rowcount ROWS.

    ENDIF.

    io_response->set_data( lt_list ).
    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( lt_list ) ).
    ENDIF.

  ENDMETHOD.
ENDCLASS.
