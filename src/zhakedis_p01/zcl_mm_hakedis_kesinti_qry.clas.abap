CLASS zcl_mm_hakedis_kesinti_qry DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.



CLASS ZCL_MM_HAKEDIS_KESINTI_QRY IMPLEMENTATION.


  METHOD if_rap_query_provider~select.
    TYPES: ty_wbs_id TYPE c LENGTH 24.
    TYPES: BEGIN OF ty_wbs_text,
             wbselement  TYPE c LENGTH 24,
             description TYPE c LENGTH 40,
           END OF ty_wbs_text.

    DATA: lt_response TYPE TABLE OF zmmr_hakedis_det_kesinti,
          ls_resp     TYPE zmmr_hakedis_det_kesinti.

    DATA(lv_offset)    = io_request->get_paging( )->get_offset( ).
    DATA(lv_page_size) = io_request->get_paging( )->get_page_size( ).

    DATA lv_ses TYPE mmpur_ses_serviceentrysheet.
    TRY.
        DATA(lt_filters) = io_request->get_filter( )->get_as_ranges( ).
        LOOP AT lt_filters INTO DATA(ls_f).
          DATA(lv_fn) = ls_f-name.
          TRANSLATE lv_fn TO UPPER CASE.
          IF lv_fn = 'SERVICEENTRYSHEET' AND lines( ls_f-range ) >= 1.
            lv_ses = ls_f-range[ 1 ]-low.
            EXIT.
          ENDIF.
        ENDLOOP.
      CATCH cx_rap_query_filter_no_range cx_root.
        CLEAR lv_ses.
    ENDTRY.

    IF lv_ses IS INITIAL.
      io_response->set_total_number_of_records( 0 ).
      io_response->set_data( lt_response ).
      RETURN.
    ENDIF.

    SELECT SINGLE yy1_purchasecontract_pdh
      FROM i_purchaseorderapi01
      WHERE purchaseorder = @lv_ses
      INTO @DATA(lv_po).

    IF lv_po IS INITIAL.
      io_response->set_total_number_of_records( 0 ).
      io_response->set_data( lt_response ).
      RETURN.
    ENDIF.

    SELECT DISTINCT interruptiontype, interruptioncurrency
      FROM zmmt_inter_log
      WHERE purchaseorder = @lv_po
        AND record_type = 'K'
      INTO TABLE @DATA(lt_types).

    " Kesinti tipi bakım tablosundan fatura ve yansıtma bilgisi
    SELECT interruptiontype, invoice_req, reflection
      FROM zmmt_inter_type
      INTO TABLE @DATA(lt_type_conf). "#EC CI_NOAUTH "#EC CI_NOWHERE

    " WBS element text: log tablosundaki WBS_ELEMENT bazlı
    SELECT DISTINCT wbs_element
      FROM zmmt_inter_log
      WHERE purchaseorder = @lv_po
        AND wbs_element NE @( CONV #( '' ) )
      INTO TABLE @DATA(lt_wbs_keys). "#EC CI_NOAUTH

    DATA lt_wbs_texts TYPE STANDARD TABLE OF string WITH EMPTY KEY.
    DATA lt_wbs TYPE STANDARD TABLE OF ty_wbs_text WITH EMPTY KEY.

    IF lt_wbs_keys IS NOT INITIAL.
      DATA lr_wbs TYPE RANGE OF ty_wbs_id.
      LOOP AT lt_wbs_keys INTO DATA(ls_wk).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_wk-wbs_element ) TO lr_wbs.
      ENDLOOP.

      SELECT node~wbselementexternalid AS wbselement,
             nodet~hierarchynodetext AS description
        FROM i_finwbselementhierarchynode AS node
        LEFT JOIN i_finwbselementhierarchynodet AS nodet
          ON  node~hierarchynode         = nodet~hierarchynode
          AND node~wbselementhierarchy   = nodet~wbselementhierarchy
          AND nodet~language             = 'T'
        WHERE node~wbselementexternalid IN @lr_wbs
        INTO TABLE @lt_wbs. "#EC CI_NOAUTH
    ENDIF.

    LOOP AT lt_types INTO DATA(ls_type).
      CLEAR ls_resp.
      ls_resp-serviceentrysheet    = lv_ses.
      ls_resp-interruptiontype     = ls_type-interruptiontype.
      ls_resp-interruptioncurrency = ls_type-interruptioncurrency.

      SELECT SINGLE interruptiontypetext
        FROM zmmt_inter_log
        WHERE interruptiontype = @ls_type-interruptiontype
        INTO @ls_resp-interruptiontypetext.

      " Varsayılan oran: log tablosundaki ilk K kaydının oranı
      SELECT SINGLE conditionrateratio
        FROM zmmt_inter_log
        WHERE purchaseorder        = @lv_po
          AND interruptiontype     = @ls_type-interruptiontype
          AND interruptioncurrency = @ls_type-interruptioncurrency
          AND record_type          = 'K'
        INTO @ls_resp-defaultinterruptionrate.

      " Fatura + yansıtma: bakım tablosundan
      READ TABLE lt_type_conf INTO DATA(ls_conf)
        WITH KEY interruptiontype = ls_type-interruptiontype.
      IF sy-subrc = 0.
        ls_resp-invoicereq  = ls_conf-invoice_req.
        ls_resp-reflection  = ls_conf-reflection.
      ENDIF.

      " WBS text: bu tip için ilk kaydın WBS element'inden
      SELECT SINGLE wbs_element
        FROM zmmt_inter_log
        WHERE purchaseorder        = @lv_po
          AND interruptiontype     = @ls_type-interruptiontype
          AND interruptioncurrency = @ls_type-interruptioncurrency
          AND wbs_element NE @( CONV #( '' ) )
        INTO @DATA(lv_wbs_el).
      IF sy-subrc = 0 AND lv_wbs_el IS NOT INITIAL.
        READ TABLE lt_wbs INTO DATA(ls_wbs_txt)
          WITH KEY wbselement = lv_wbs_el.
        IF sy-subrc = 0.
          ls_resp-wbselementtext = ls_wbs_txt-description.
        ENDIF.
      ENDIF.

      " Önceki: KDV hariç (amount) + KDV dahil (amountwithtax)
      SELECT SUM( amount ), SUM( amountwithtax )
        FROM zmmt_inter_log
        WHERE purchaseorder        = @lv_po
          AND interruptiontype     = @ls_type-interruptiontype
          AND interruptioncurrency = @ls_type-interruptioncurrency
          AND record_type          = 'K'
          AND serviceentrysheet   NE @lv_ses
        INTO ( @ls_resp-previnterruptionamount, @ls_resp-previnterruptionamounttax ).

      " Şimdiki: KDV hariç (amount) + KDV dahil (amountwithtax)
      SELECT SUM( amount ), SUM( amountwithtax )
        FROM zmmt_inter_log
        WHERE purchaseorder        = @lv_po
          AND interruptiontype     = @ls_type-interruptiontype
          AND interruptioncurrency = @ls_type-interruptioncurrency
          AND record_type          = 'K'
          AND serviceentrysheet    = @lv_ses
        INTO ( @ls_resp-currinterruptionamount, @ls_resp-currinterruptionamounttax ).

      ls_resp-totalinterruptionamount    = ls_resp-previnterruptionamount
                                         + ls_resp-currinterruptionamount.
      ls_resp-totalinterruptionamounttax = ls_resp-previnterruptionamounttax
                                         + ls_resp-currinterruptionamounttax.

      APPEND ls_resp TO lt_response.
    ENDLOOP.

    io_response->set_total_number_of_records( lines( lt_response ) ).

    IF lv_page_size > 0.
      DATA(lv_max) = lv_offset + lv_page_size.
      IF lv_max > lines( lt_response ).
        lv_max = lines( lt_response ).
      ENDIF.
      DATA lt_page TYPE TABLE OF zmmr_hakedis_det_kesinti.
      LOOP AT lt_response INTO DATA(ls_pg) FROM ( lv_offset + 1 ) TO lv_max.
        APPEND ls_pg TO lt_page.
      ENDLOOP.
      io_response->set_data( lt_page ).
    ELSE.
      io_response->set_data( lt_response ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
