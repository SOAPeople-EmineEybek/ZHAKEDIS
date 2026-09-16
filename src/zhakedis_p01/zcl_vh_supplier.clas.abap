CLASS zcl_vh_supplier DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.



CLASS ZCL_VH_SUPPLIER IMPLEMENTATION.


  METHOD if_rap_query_provider~select.
    DATA lt_result TYPE TABLE OF zmmr_vh_supplier.

    " RAP runtime requires these calls
    DATA(lv_offset)    = io_request->get_paging( )->get_offset( ).
    DATA(lv_page_size) = io_request->get_paging( )->get_page_size( ).
    DATA(lt_sort)      = io_request->get_sort_elements( ).

    SELECT supplier, suppliername
      FROM i_supplier
      INTO TABLE @DATA(lt_raw)."#EC CI_NOWHERE

    TRY.
        DATA(lt_filters) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range."#EC NO_HANDLER
##NO_HANDLER
    ENDTRY.

    LOOP AT lt_filters INTO DATA(ls_f).
      CASE ls_f-name.
        WHEN 'SUPPLIER'.     DELETE lt_raw WHERE supplier NOT IN ls_f-range.
        WHEN 'SUPPLIERNAME'. DELETE lt_raw WHERE suppliername NOT IN ls_f-range.
      ENDCASE.
    ENDLOOP.

    LOOP AT lt_raw INTO DATA(ls_raw).
      APPEND VALUE #( supplier = ls_raw-supplier
                      suppliername = ls_raw-suppliername ) TO lt_result.
    ENDLOOP.

    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( lt_result ) ).
    ENDIF.
    IF io_request->is_data_requested( ).
      io_response->set_data( lt_result ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
