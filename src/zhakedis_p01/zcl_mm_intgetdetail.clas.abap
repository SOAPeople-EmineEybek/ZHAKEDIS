CLASS zcl_mm_intgetdetail DEFINITION
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



CLASS zcl_mm_intgetdetail IMPLEMENTATION.


  METHOD handle_paging.
    DATA(offset) = i_io_request->get_paging(  )->get_offset( ).
    DATA(page_size) = i_io_request->get_paging(  )->get_page_size(  ).
    DATA(max_rows) = COND #( WHEN page_size = if_rap_query_paging=>page_size_unlimited THEN 0 ELSE page_size ).
  ENDMETHOD.


  METHOD if_rap_query_provider~select.

    DATA: ls_impdata           TYPE zmms_int_detail_imp,
          lt_return            TYPE TABLE OF zmmr_int_getdetail,
          lt_item              TYPE zmmtt_int_save,
          lt_tutanak           TYPE zmmtt_int_save,
          lv_serviceentrysheet TYPE mmpur_ses_serviceentrysheet,
          lv_purchaseorder     TYPE ebeln,
          lv_status            TYPE zmmd_intstatu,
          lv_statust           TYPE c LENGTH 20,
          lv_active            TYPE abap_boolean.

    handle_paging( io_request ).
    DATA(filters) = io_request->get_filter(  ).
    IF io_request->is_data_requested(  ).
      TRY.
          DATA(ranges) = filters->get_as_ranges(  ).
        CATCH cx_rap_query_filter_no_range.             "#EC NO_HANDLER
      ENDTRY.

      IF line_exists( ranges[ name = 'FILTER' ] ).
        DATA(lr_filter) = VALUE #( ranges[ name = 'FILTER' ]-range ).
        READ TABLE lr_filter INTO DATA(ls_filter) INDEX 1.
        IF ls_filter-low IS NOT INITIAL.
          /ui2/cl_json=>deserialize( EXPORTING json = ls_filter-low pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = ls_impdata ).
        ENDIF.
      ENDIF.
    ENDIF.

    CLEAR: lv_serviceentrysheet, lv_purchaseorder, lt_item, lv_active.
    lv_serviceentrysheet = |{ ls_impdata-serviceentrysheet ALPHA = IN }|.
    lv_purchaseorder = |{ ls_impdata-purchaseorder ALPHA = IN }|.

    " PO (Hakediş) ilk kaleminin PYP ön eki (2. noktaya kadar, ör. "X5.02.") — bir kez hesaplanır.
    " Kullanım: (a) ilk açılıştaki oto-satırların default PYP'si, (b) response'taki PypPrefix ile
    " frontend'in MANUEL eklenen satırlara PYP önerisi (ön ek + türün pyp_suffix'i).
    DATA(lv_pyp_prefix) = zcl_mm_int_gen=>get_pyp_prefix( CONV #( lv_serviceentrysheet ) ).

    " Tedarikçi adı — Hakediş (PO) üzerinden. (Eski model: i_serviceentrysheetapi01.)
    SELECT SINGLE supplier, suppliername
      FROM i_supplier
      WHERE supplier = ( SELECT supplier FROM i_purchaseorderapi01
                         WHERE purchaseorder = @lv_serviceentrysheet )
      INTO @DATA(ls_supp).

    " Kesinti kayıtları (K)
    SELECT purchaseorder, serviceentrysheet, record_type,
           item AS lineno, plant, interruptioncurrency, netpriceamount,
           statu, interruptiontype, interruptiontypetext, amount,
           taxcode, conditionrateratio, amountwithtax, note,
           wbs_element, invoice_req, reflection
      FROM zmmt_inter_log
     WHERE serviceentrysheet = @lv_serviceentrysheet
       AND purchaseorder = @lv_purchaseorder
       AND record_type = 'K'
      INTO CORRESPONDING FIELDS OF TABLE @lt_item.

    " Tutanak kayıtları (T)
    SELECT purchaseorder, serviceentrysheet, record_type,
           item AS lineno, plant, interruptioncurrency, netpriceamount,
           statu, interruptiontype, interruptiontypetext, amount,
           taxcode, conditionrateratio, amountwithtax, note,
           wbs_element, invoice_req, reflection
      FROM zmmt_inter_log
     WHERE serviceentrysheet = @lv_serviceentrysheet
       AND purchaseorder = @lv_purchaseorder
       AND record_type = 'T'
      INTO CORRESPONDING FIELDS OF TABLE @lt_tutanak.

    IF lt_item IS NOT INITIAL.
      lv_status = VALUE #( lt_item[ 1 ]-statu OPTIONAL ).
      IF lv_status EQ '1'.
        lv_statust = 'İşleniyor'.
        lv_active = 'X'.
      ELSEIF lv_status EQ '2'.
        lv_statust = 'Kapatıldı'.
        lv_active = ''.
      ENDIF.
    ELSE.
      lv_status = '1'.
      lv_statust = 'İşleniyor'.
      lv_active = 'X'.
    ENDIF.

    " Bakım tablosu
    SELECT *
      FROM zmmt_inter_type
      INTO TABLE @DATA(lt_itype_all).                   "#EC CI_NOWHERE

    " İlk açılış — otomatik satır oluştur
    IF lt_item IS INITIAL.

      SELECT SINGLE *                         "#EC CI_ALL_FIELDS_NEEDED
        FROM i_purchaseorderAPI01
       WHERE purchaseorder = @lv_serviceentrysheet
        INTO @DATA(ls_po_full).

      SELECT SUM( CASE poit~isreturnsitem WHEN 'X' THEN poit~netamount * -1
                                                   ELSE poit~netamount END ) AS netamount,
              SUM( poit~netamount ) AS tax
        FROM i_purchaseorderitemapi01 AS poit
       WHERE purchaseorder = @lv_serviceentrysheet
        INTO @DATA(ls_hakedis).

      SELECT ( CASE poit~isreturnsitem WHEN 'X' THEN poit~netamount * -1
                                                ELSE poit~netamount END ) AS netamount,
                tax~conditionrateratio
      FROM i_purchaseorderitemapi01 AS poit
      LEFT JOIN i_taxcoderate AS tax
             ON poit~taxcode          EQ tax~taxcode
            AND tax~VATConditionType  EQ 'ZTRA'
     WHERE purchaseorder EQ @lv_serviceentrysheet
      INTO TABLE @DATA(lt_hkd_tvk).

      CLEAR: ls_hakedis-tax.
      LOOP AT lt_hkd_tvk INTO DATA(ls_hkd_tvk) WHERE conditionrateratio IS NOT INITIAL.
        ls_hakedis-tax = ls_hakedis-tax + ( ls_hkd_tvk-netamount * ls_hkd_tvk-conditionrateratio / -100  ).
      ENDLOOP.

      SELECT *
        FROM zmmt_inter_type
       WHERE custom_field IS NOT INITIAL
        INTO TABLE @DATA(lt_auto_types).

      DATA ls_auto_item TYPE zmms_int_save.
      DATA(lv_lineno) = 0.
      DATA lv_fieldval TYPE p LENGTH 8 DECIMALS 2.

      LOOP AT lt_auto_types INTO DATA(ls_atype).
        CLEAR lv_fieldval.
        ASSIGN COMPONENT ls_atype-custom_field OF STRUCTURE ls_po_full TO FIELD-SYMBOL(<fs_val>).
        IF sy-subrc IS INITIAL AND <fs_val> IS ASSIGNED.
          lv_fieldval = <fs_val>.
        ENDIF.

        IF lv_fieldval <> 0 OR ( ls_atype-custom_field EQ 'KDV_TEVKIFATI' AND ls_hakedis-tax IS NOT INITIAL ).
          lv_lineno = lv_lineno + 1.
          CLEAR ls_auto_item.
          ls_auto_item-purchaseorder        = lv_purchaseorder.
          ls_auto_item-serviceentrysheet    = lv_serviceentrysheet.
          ls_auto_item-lineno               = lv_lineno.
          ls_auto_item-record_type          = 'K'.
          ls_auto_item-interruptiontype     = ls_atype-interruptiontype.
          ls_auto_item-interruptiontypetext = ls_atype-interruptiontypetxt.
          IF ls_atype-custom_field EQ 'KDV_TEVKIFATI'.
            ls_auto_item-amount               = ls_hakedis-tax.
          ELSE.
            ls_auto_item-amount               = ls_hakedis-netamount * lv_fieldval / 100.
          ENDIF.
          ls_auto_item-taxcode              = ''.
          ls_auto_item-conditionrateratio   = lv_fieldval.
          ls_auto_item-interruptioncurrency = ls_po_full-documentcurrency.
          ls_auto_item-statu                = '1'.
          ls_auto_item-amountwithtax        = ls_auto_item-amount.
          ls_auto_item-invoice_req          = ls_atype-invoice_req.
          ls_auto_item-reflection           = ls_atype-reflection.
          " Default PYP = PO ön eki + kesinti türünün "PYP son eki".
          " Bu blok yalnızca hiç kayıt yokken (ilk açılış) çalışır. PYP bir kez önerilmiş olur;
          " kullanıcı değiştirip kaydederse sonraki açılışlarda saklanan PYP korunur.
          IF lv_pyp_prefix IS NOT INITIAL AND ls_atype-pyp_suffix IS NOT INITIAL.
            ls_auto_item-wbs_element = |{ lv_pyp_prefix }{ condense( CONV string( ls_atype-pyp_suffix ) ) }|.
          ENDIF.
          APPEND ls_auto_item TO lt_item.
        ENDIF.
      ENDLOOP.

    ELSE.
      " Mevcut satırlar — bakım tablosundan güncelle
      LOOP AT lt_item ASSIGNING FIELD-SYMBOL(<fs_item>).
        READ TABLE lt_itype_all INTO DATA(ls_it_exist)
            WITH KEY interruptiontype = <fs_item>-interruptiontype.
        IF sy-subrc IS INITIAL.
          <fs_item>-invoice_req = ls_it_exist-invoice_req.
          <fs_item>-reflection  = ls_it_exist-reflection.
        ENDIF.
      ENDLOOP.
    ENDIF.

    " Bakım tablosu JSON (frontend için)
    /ui2/cl_json=>serialize( EXPORTING data = lt_itype_all pretty_name = /ui2/cl_json=>pretty_mode-camel_case RECEIVING r_json = DATA(lv_itype_json) ).

    " Kesinti + Tutanak birlikte
    TYPES: BEGIN OF ty_combined,
             tdata   TYPE zmmtt_int_save,
             tdata_t TYPE zmmtt_int_save,
           END OF ty_combined.
    DATA: ls_combined TYPE ty_combined,
          lt_combined TYPE TABLE OF ty_combined.

    ls_combined-tdata   = lt_item.
    ls_combined-tdata_t = lt_tutanak.
    APPEND ls_combined TO lt_combined.

    /ui2/cl_json=>serialize( EXPORTING data = lt_combined pretty_name = /ui2/cl_json=>pretty_mode-camel_case RECEIVING r_json = DATA(lv_res_json) ).

    APPEND INITIAL LINE TO lt_return ASSIGNING FIELD-SYMBOL(<fs_return>).
    <fs_return>-evjson    = lv_res_json.
    <fs_return>-status    = lv_status.
    <fs_return>-statust   = lv_statust.
    <fs_return>-filter    = lv_itype_json.
    <fs_return>-active    = lv_active.
    <fs_return>-treetable = ls_supp-suppliername.
    <fs_return>-pypprefix = lv_pyp_prefix.   " Frontend manuel satır PYP önerisi (ön ek + tür pyp_suffix'i)

    io_response->set_data( lt_return ).
    IF io_request->is_total_numb_of_rec_requested(  ).

      io_response->set_total_number_of_records( lines( lt_return ) ).

    ENDIF.

  ENDMETHOD.
ENDCLASS.
