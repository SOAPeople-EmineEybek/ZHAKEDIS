CLASS zcl_mm_hakedis_tutanak_qry DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.


CLASS zcl_mm_hakedis_tutanak_qry IMPLEMENTATION.

  METHOD if_rap_query_provider~select.
    TYPES: ty_wbs_id TYPE c LENGTH 24.
    TYPES: BEGIN OF ty_wbs_text,
             wbselement  TYPE c LENGTH 24,
             description TYPE c LENGTH 40,
           END OF ty_wbs_text.

    DATA: lt_response TYPE TABLE OF zmmr_hakedis_det_tutanak,
          ls_resp     TYPE zmmr_hakedis_det_tutanak.

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

    SELECT SINGLE yy1_purchasecontract_pdh AS purchaseorder
      FROM i_purchaseorderapi01
      WHERE purchaseorder = @lv_ses
      INTO @DATA(lv_po).

    IF lv_po IS INITIAL.
      io_response->set_total_number_of_records( 0 ).
      io_response->set_data( lt_response ).
      RETURN.
    ENDIF.

*Tutanak kayıtları
    SELECT itm~purchaseorder         AS serviceentrysheet,
           itm~purchaseorderitem     AS item,
           itm~material              AS interruptiontype,
           itm~PurchaseorderItemText AS interruptiontypetext,
           wbs~ProjectElement            AS wbs_element,
           wbs~ProjectElementDescription AS wbselementtext,
           itm~documentcurrency      AS interruptioncurrency,
           itm~netpriceamount,
           itm~netamount             AS amount,
           itm~netamount             AS amountwithtax,
           'X'                       AS invoice_req,
           itm~YY1_Yanstma_PDI       AS reflection, "Z'li alanı bağla.
           itm~taxcode               AS  taxcode,
           tax~conditionrateratio,
           itm~PurchaseorderItemText AS note,
           '1' AS statu
    FROM i_purchaseorderitemapi01 AS itm LEFT JOIN I_PurOrdAccountAssignmentAPI01 AS acc
      ON itm~purchaseorder     EQ acc~purchaseorder
     AND itm~purchaseorderitem EQ acc~purchaseorderitem
     LEFT JOIN i_taxcoderate AS tax
     ON itm~taxcode          EQ tax~taxcode
    AND tax~VATConditionType EQ 'MWVS'
    LEFT JOIN I_EnterpriseProjectElement AS wbs
      ON acc~WBSElementInternalID_2 EQ wbs~WBSElementInternalID
    WHERE itm~purchaseorder = @lv_ses
      AND materialgroup = 'TUTANAK'
      AND PurchasingDocumentDeletionCode = ''
    INTO TABLE @DATA(lt_tutanak).                        "#EC CI_NOAUTH

    LOOP AT lt_tutanak ASSIGNING FIELD-SYMBOL(<row>).
      CLEAR ls_resp.
      ls_resp-serviceentrysheet    = <row>-serviceentrysheet.
      ls_resp-item                 = <row>-item.
      ls_resp-interruptiontype     = <row>-interruptiontype.
      ls_resp-interruptiontypetext = <row>-interruptiontypetext.
      ls_resp-wbselement           = <row>-wbs_element.
      ls_resp-wbselementtext       = <row>-wbselementtext.
      ls_resp-interruptioncurrency = <row>-interruptioncurrency.
      ls_resp-netpriceamount       = <row>-netpriceamount.
      ls_resp-amount               = <row>-amount.
      ls_resp-invoicereq           = <row>-invoice_req.
      ls_resp-reflection           = <row>-reflection.
      ls_resp-taxcode              = <row>-taxcode.
      ls_resp-conditionrateratio   = <row>-conditionrateratio.
      ls_resp-note                 = <row>-note.
      ls_resp-status               = <row>-statu.
      ls_resp-amountwithtax        = ls_resp-amount + ( <row>-amount * <row>-conditionrateratio / 100 ).


      APPEND ls_resp TO lt_response.
    ENDLOOP.

    io_response->set_total_number_of_records( lines( lt_response ) ).

    IF lv_page_size > 0.
      DATA(lv_max) = lv_offset + lv_page_size.
      IF lv_max > lines( lt_response ).
        lv_max = lines( lt_response ).
      ENDIF.
      DATA lt_page TYPE TABLE OF zmmr_hakedis_det_tutanak.
      LOOP AT lt_response INTO DATA(ls_pg) FROM ( lv_offset + 1 ) TO lv_max.
        APPEND ls_pg TO lt_page.
      ENDLOOP.
      io_response->set_data( lt_page ).
    ELSE.
      io_response->set_data( lt_response ).
    ENDIF.

  ENDMETHOD.
ENDCLASS.
