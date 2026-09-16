CLASS zcl_vh_int_statu DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.



CLASS ZCL_VH_INT_STATU IMPLEMENTATION.


  METHOD if_rap_query_provider~select.
    DATA lt_result TYPE TABLE OF zmmr_vh_int_statu.

    " RAP runtime requires these calls
    DATA(lv_offset)    = io_request->get_paging( )->get_offset( ).
    DATA(lv_page_size) = io_request->get_paging( )->get_page_size( ).
    DATA(lt_sort)      = io_request->get_sort_elements( ).

    lt_result = VALUE #(
      ( statuscode = ' ' statustext = 'Kesinti girişi yok' )
      ( statuscode = 'P' statustext = 'Kesinti girişi devam ediyor' )
      ( statuscode = 'S' statustext = 'Kesinti girişi tamamlanmış' )
    ).

    TRY.
        DATA(lt_filters) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range."#EC NO_HANDLER
##NO_HANDLER
    ENDTRY.

    LOOP AT lt_filters INTO DATA(ls_f).
      CASE ls_f-name.
        WHEN 'STATUSCODE'. DELETE lt_result WHERE statuscode NOT IN ls_f-range.
        WHEN 'STATUSTEXT'. DELETE lt_result WHERE statustext NOT IN ls_f-range.
      ENDCASE.
    ENDLOOP.

    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( lt_result ) ).
    ENDIF.
    IF io_request->is_data_requested( ).
      io_response->set_data( lt_result ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
