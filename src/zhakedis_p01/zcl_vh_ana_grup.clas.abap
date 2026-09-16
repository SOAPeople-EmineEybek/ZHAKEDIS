CLASS zcl_vh_ana_grup DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.



CLASS ZCL_VH_ANA_GRUP IMPLEMENTATION.


  METHOD if_rap_query_provider~select.
    DATA lt_result TYPE TABLE OF zmmr_vh_ana_grup.

    " RAP runtime requires these calls
    DATA(lv_offset)    = io_request->get_paging( )->get_offset( ).
    DATA(lv_page_size) = io_request->get_paging( )->get_page_size( ).
    DATA(lt_sort)      = io_request->get_sort_elements( ).

    lt_result = VALUE #(
      ( code = '1' description = 'ANA SÖZLEŞME' )
      ( code = '2' description = 'EK MUTABAKAT (YENİ BİRİM FİYAT)' )
      ( code = '3' description = 'EK MUTABAKAT (FİYAT FARKI)' )
      ( code = '4' description = 'EK MUTABAKAT (YENİ B.FİYAT + FİYAT FARKI)' )
      ( code = '5' description = 'FESİH PROTOKOLÜ' )
      ( code = '6' description = 'ALT YÜKLENİCİ TAAHHÜTNAMESİ' )
      ( code = '7' description = 'GARANTÖRLÜk SÖZLEŞME' )
    ).

    TRY.
        DATA(lt_filters) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range."#EC NO_HANDLER
##NO_HANDLER
    ENDTRY.

    LOOP AT lt_filters INTO DATA(ls_f).
      CASE ls_f-name.
        WHEN 'CODE'.        DELETE lt_result WHERE code NOT IN ls_f-range.
        WHEN 'DESCRIPTION'. DELETE lt_result WHERE description NOT IN ls_f-range.
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
