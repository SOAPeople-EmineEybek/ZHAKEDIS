CLASS zcl_mm_shtaxcode DEFINITION
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



CLASS ZCL_MM_SHTAXCODE IMPLEMENTATION.


  METHOD handle_paging.
    DATA(offset) = i_io_request->get_paging(  )->get_offset( ).
    DATA(page_size) = i_io_request->get_paging(  )->get_page_size(  ).
    DATA(max_rows) = COND #( WHEN page_size = if_rap_query_paging=>page_size_unlimited THEN 0 ELSE page_size ).
  ENDMETHOD.


  METHOD if_rap_query_provider~select.

    DATA lt_list TYPE STANDARD TABLE OF zmmr_shtaxcode.
    DATA lr_taxcode TYPE RANGE OF mwskz.
    DATA lv_interruptiontype TYPE zmmd_interrupt_type_v2.

    IF io_request->is_data_requested(  ).
      handle_paging( io_request ).

      DATA(lo_filter) = io_request->get_filter(  ).
      TRY.
          DATA(ranges) = lo_filter->get_as_ranges(  ).
        CATCH cx_rap_query_filter_no_range."#EC NO_HANDLER
      ENDTRY.

      " Kesinti türü
      IF line_exists( ranges[ name = 'INTERRUPTIONTYPE' ] ).
        DATA(lrt_itype) = VALUE #( ranges[ name = 'INTERRUPTIONTYPE' ]-range ).
        READ TABLE lrt_itype INTO DATA(ls_itype) INDEX 1.
        IF sy-subrc IS INITIAL.
          lv_interruptiontype = ls_itype-low.
        ENDIF.
      ENDIF.

      " Boş
      IF lv_interruptiontype IS INITIAL.
        io_response->set_data( lt_list ).
        IF io_request->is_total_numb_of_rec_requested(  ).
          io_response->set_total_number_of_records( 0 ).
        ENDIF.
        RETURN.
      ENDIF.

      " ALL = tüm vergi kodları
      IF lv_interruptiontype <> 'ALL'.
        "Kesinti türüne göre izin verilen kodlar
        SELECT taxcode
          FROM zmmt_inter_tax
         WHERE interruptiontype = @lv_interruptiontype
          INTO TABLE @DATA(lt_allowed).

        IF lt_allowed IS INITIAL.
          io_response->set_data( lt_list ).
          IF io_request->is_total_numb_of_rec_requested(  ).
            io_response->set_total_number_of_records( 0 ).
          ENDIF.
          RETURN.
        ENDIF.

        LOOP AT lt_allowed INTO DATA(ls_a).
          APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_a-taxcode ) TO lr_taxcode.
        ENDLOOP.
      ENDIF.

      DATA(lv_offset) = io_request->get_paging(  )->get_offset( ).
      DATA(lv_rowcount) = io_request->get_paging(  )->get_page_size(  ).

      " Vergi kodları
      DATA(lv_today) = cl_abap_context_info=>get_system_date( ).

      SELECT i_taxcodetext~taxcode,
             taxcodename,
             i_taxcoderate~conditionrateratio
        FROM i_taxcodetext
        INNER JOIN i_taxcoderate ON i_taxcoderate~taxcode = i_taxcodetext~taxcode
                                AND i_taxcoderate~taxcalculationprocedure = i_taxcodetext~taxcalculationprocedure
        WHERE language = 'T'
          AND i_taxcodetext~taxcode IN @lr_taxcode
          AND i_taxcoderate~cndnrecordvaliditystartdate <= @lv_today
          AND i_taxcoderate~cndnrecordvalidityenddate >= @lv_today
        ORDER BY i_taxcodetext~taxcode
        INTO CORRESPONDING FIELDS OF TABLE @lt_list
        OFFSET @lv_offset
        UP TO @lv_rowcount ROWS.

    ENDIF.

    io_response->set_data( lt_list ).
    IF io_request->is_total_numb_of_rec_requested(  ).
      io_response->set_total_number_of_records( lines( lt_list ) ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
