CLASS zcl_vh_purchaseorder DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.



CLASS ZCL_VH_PURCHASEORDER IMPLEMENTATION.


  METHOD if_rap_query_provider~select.
    DATA lt_result TYPE TABLE OF zmmr_vh_purchaseorder.

    " RAP runtime requires these calls
    DATA(lv_offset)    = io_request->get_paging( )->get_offset( ).
    DATA(lv_page_size) = io_request->get_paging( )->get_page_size( ).
    DATA(lt_sort)      = io_request->get_sort_elements( ).

    SELECT po~purchasecontract as purchaseorder, po~supplier, sup~suppliername
      FROM I_PurchaseContractAPI01 AS po
      LEFT JOIN i_supplier AS sup ON po~supplier = sup~supplier
      WHERE po~PurchaseContractType = 'Z004'
      INTO TABLE @DATA(lt_raw).

    TRY.
        DATA(lt_filters) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range."#EC NO_HANDLER
##NO_HANDLER
    ENDTRY.

    LOOP AT lt_filters INTO DATA(ls_f).
      CASE ls_f-name.
        WHEN 'PURCHASEORDER'. DELETE lt_raw WHERE purchaseorder NOT IN ls_f-range.
        WHEN 'SUPPLIER'.      DELETE lt_raw WHERE supplier NOT IN ls_f-range.
      ENDCASE.
    ENDLOOP.

    LOOP AT lt_raw INTO DATA(ls_raw).
      APPEND VALUE #( purchaseorder = ls_raw-purchaseorder
                      supplier      = ls_raw-supplier
                      suppliername  = ls_raw-suppliername ) TO lt_result.
    ENDLOOP.

    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( lt_result ) ).
    ENDIF.
    IF io_request->is_data_requested( ).
      io_response->set_data( lt_result ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
