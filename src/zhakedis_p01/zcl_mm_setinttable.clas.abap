CLASS zcl_mm_setinttable DEFINITION
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



CLASS ZCL_MM_SETINTTABLE IMPLEMENTATION.


  METHOD handle_paging.
    DATA(offset) = i_io_request->get_paging(  )->get_offset( ).
    DATA(page_size) = i_io_request->get_paging(  )->get_page_size(  ).
    DATA(max_rows) = COND #( WHEN page_size = if_rap_query_paging=>page_size_unlimited THEN 0 ELSE page_size ).
  ENDMETHOD.


  METHOD if_rap_query_provider~select.

    DATA: ls_request           TYPE zmms_int_imp_create,
          lt_impitems          TYPE zmmtt_int_save,
          lv_serviceentrysheet TYPE mmpur_ses_serviceentrysheet,
          lt_return            TYPE TABLE OF zmmr_int_settable,
          lt_message           TYPE zmmtt_intmessage,
          lv_status            TYPE zmmd_intstatu,
          lv_statust           TYPE c LENGTH 20,
          lv_amount            TYPE zmmd_mmpur_ses_item_netprice.

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
          /ui2/cl_json=>deserialize( EXPORTING json = ls_filter-low pretty_name = /ui2/cl_json=>pretty_mode-camel_case CHANGING data = ls_request ).
        ENDIF.
      ENDIF.
    ENDIF.

    DATA(lo_json) = NEW /ui2/cl_json( ).
    lo_json->deserialize( EXPORTING json = ls_request-ivjson CHANGING data = lt_impitems ).
    lv_serviceentrysheet = ls_request-iv_serviceentrysheet.
    lv_serviceentrysheet = |{ ls_request-iv_serviceentrysheet ALPHA = IN }|.

    DATA: ls_item TYPE zmmt_inter_log,
          lt_item TYPE TABLE OF zmmt_inter_log,
          lv_flag TYPE c LENGTH 1.

    " Bakım tablosu
    SELECT * FROM zmmt_inter_type INTO TABLE @DATA(lt_itype). "#EC CI_NOWHERE

    " Kullanılabilir vergi kodları
    SELECT * FROM zmmt_inter_tax INTO TABLE @DATA(lt_inter_tax). "#EC CI_NOWHERE

    " Duplike kesinti türü kontrolü
    DATA lt_used_types TYPE SORTED TABLE OF zmmd_interrupt_type_v2 WITH UNIQUE KEY table_line.

    " PO'dan tutanak limitlerini al
    DATA lv_po TYPE ebeln.
    READ TABLE lt_impitems INTO DATA(ls_first) INDEX 1.
    IF sy-subrc IS INITIAL.
      lv_po = ls_first-purchaseorder.
    ENDIF.

    SELECT SINGLE yy1_tutanaklimiti_pdh, yy1_tutanaklimiti_pdhc
      FROM I_PurchaseContractAPI01
     WHERE purchasecontract = @lv_po
      INTO @DATA(ls_po_limits).

    " Mevcut kapatılmış tutanakların toplamı
    DATA lv_existing_tutanak_total TYPE zmmd_mmpur_ses_item_netprice.
    SELECT SUM( amount )
      FROM zmmt_inter_log
     WHERE purchaseorder = @lv_po
       AND record_type = 'T'
       AND statu = '2'
      INTO @lv_existing_tutanak_total.

    DATA lv_new_tutanak_total TYPE zmmd_mmpur_ses_item_netprice.

    " Tüm satırları işle
    LOOP AT lt_impitems INTO DATA(ls_d).
      CLEAR ls_item.
      MOVE-CORRESPONDING ls_d TO ls_item.
      ls_item-serviceentrysheet = lv_serviceentrysheet.
      ls_item-purchaseorder = |{ ls_d-purchaseorder ALPHA = IN }|.
      ls_item-item = ls_d-lineno.
      ls_item-statu = '1'.
      ls_item-local_last_changed_at = cl_abap_context_info=>get_system_date( ).
      ls_item-local_last_changed_by = cl_abap_context_info=>get_user_technical_name( ).

      IF ls_d-record_type = 'K'.
        "KESİNTİ
        ls_item-record_type = 'K'.

        " KDV tutarları — backend OTORİTATİF hesaplar. Oran = conditionrateratio (%).
        " Kullanıcı KDV DAHİL girer → hariç = dahil / (1 + oran/100).
        " (Yalnızca hariç gelmişse dahil = hariç × (1 + oran/100) ile tamamlanır; oran 0 ise dahil = hariç.)
        DATA lv_rate_factor TYPE decfloat34.
        lv_rate_factor = 1 + ls_item-conditionrateratio / 100.
        IF ls_item-amountwithtax IS NOT INITIAL AND lv_rate_factor <> 0.
          ls_item-amount        = ls_item-amountwithtax / lv_rate_factor.
        ELSEIF ls_item-amount IS NOT INITIAL.
          ls_item-amountwithtax = ls_item-amount * lv_rate_factor.
        ENDIF.

        IF ls_item-amount IS INITIAL.
          lv_flag = 'X'.
          APPEND VALUE #( type = 'E' message = |Kesinti { ls_d-lineno }: Tutar boş olamaz| ) TO lt_message.
        ENDIF.

        " Kesinti türü bakım kaydını önce oku (PYP zorunluluğu + diğer kontroller için).
        READ TABLE lt_itype INTO DATA(ls_it) WITH KEY interruptiontype = ls_item-interruptiontype.
        DATA(lv_type_found) = xsdbool( sy-subrc = 0 ).

        " PYP zorunluluğu: yalnızca bakım tablosunda WBS_REQ='X' işaretli türlerde zorunlu.
        " (İşaretsizse PYP boş bırakılabilir.)
        IF lv_type_found = abap_true AND ls_it-wbs_req = 'X' AND ls_d-wbs_element IS INITIAL.
          lv_flag = 'X'.
          APPEND VALUE #( type = 'E' message = |Kesinti { ls_d-lineno }: PYP zorunludur| ) TO lt_message.
        ENDIF.
        ls_item-wbs_element = ls_d-wbs_element.

        IF lv_type_found = abap_true.
          ls_item-invoice_req = ls_it-invoice_req.
          ls_item-reflection  = ls_it-reflection.

          " Vergi zorunluluk tax_entry_req = X zorunlu
          IF ls_it-tax_entry_req = 'X' AND ls_item-taxcode IS INITIAL.
            lv_flag = 'X'.
            APPEND VALUE #( type = 'E' message = |Kesinti { ls_d-lineno }: { ls_it-interruptiontypetxt } için vergi göstergesi zorunlu| ) TO lt_message.
          ENDIF.

          " Vergi değer kontrolü (zmmt_inter_tax)
          IF ls_item-taxcode IS NOT INITIAL.
            READ TABLE lt_inter_tax WITH KEY interruptiontype = ls_item-interruptiontype
                                             taxcode = ls_item-taxcode
                                    TRANSPORTING NO FIELDS.
            IF sy-subrc IS NOT INITIAL.
              lv_flag = 'X'.
              APPEND VALUE #( type = 'E' message = |Kesinti { ls_d-lineno }: { ls_item-taxcode } bu kesinti türünde kullanılamaz| ) TO lt_message.
            ENDIF.
          ENDIF.

          " Negatif kontrol
          IF ls_it-acc_doc_type_neg IS INITIAL AND ls_item-amount < 0.
            lv_flag = 'X'.
            APPEND VALUE #( type = 'E' message = |Kesinti { ls_d-lineno }: Negatif değer girilemez| ) TO lt_message.
          ENDIF.
        ENDIF.

        " Duplike kesinti türü
        INSERT ls_item-interruptiontype INTO TABLE lt_used_types.
        IF sy-subrc IS NOT INITIAL.
          lv_flag = 'X'.
          APPEND VALUE #( type = 'E' message = |Kesinti { ls_d-lineno }: { ls_item-interruptiontype } zaten kullanılmış| ) TO lt_message.
        ENDIF.

      ELSEIF ls_d-record_type = 'T'.
        " ===== TUTANAK SATIRLARI =====
        ls_item-record_type = 'T'.
        ls_item-wbs_element = ls_d-wbs_element.
        ls_item-reflection  = ls_d-reflection.

        " KDV tutarları — backend OTORİTATİF (kesinti ile aynı): kullanıcı KDV DAHİL girer →
        " net = dahil / (1 + oran/100). Oran negatif olabilir (tevkifat vb.); faktör 0 ise net = dahil.
        lv_rate_factor = 1 + ls_item-conditionrateratio / 100.
        IF ls_item-amountwithtax IS NOT INITIAL AND lv_rate_factor <> 0.
          ls_item-amount        = ls_item-amountwithtax / lv_rate_factor.
        ELSEIF ls_item-amount IS NOT INITIAL.
          ls_item-amountwithtax = ls_item-amount * lv_rate_factor.
        ENDIF.

        IF ls_d-wbs_element IS INITIAL.
          lv_flag = 'X'.
          APPEND VALUE #( type = 'E' message = |Tutanak { ls_d-lineno }: PYP zorunludur| ) TO lt_message.
        ENDIF.

        IF ls_item-amount IS INITIAL.
          lv_flag = 'X'.
          APPEND VALUE #( type = 'E' message = |Tutanak { ls_d-lineno }: Net tutar zorunludur| ) TO lt_message.
        ENDIF.

        " Kalem limit kontrolü
        IF ls_po_limits-yy1_tutanaklimiti_pdh > 0
           AND ls_item-amount > ls_po_limits-yy1_tutanaklimiti_pdh.
          lv_flag = 'X'.
          APPEND VALUE #( type = 'E' message = |Tutanak { ls_d-lineno }: Tek seferde max { ls_po_limits-yy1_tutanaklimiti_pdh } girilebilir| ) TO lt_message.
        ENDIF.

        lv_new_tutanak_total = lv_new_tutanak_total + ls_item-amount.
      ENDIF.

      APPEND ls_item TO lt_item.
    ENDLOOP.

    " Toplam tutanak limit kontrolü
    IF ls_po_limits-yy1_tutanaklimiti_pdh > 0
       AND ( lv_existing_tutanak_total + lv_new_tutanak_total ) > ls_po_limits-yy1_tutanaklimiti_pdh.
      lv_flag = 'X'.
      APPEND VALUE #( type = 'E' message = |Toplam tutanak limiti aşıldı. Limit: { ls_po_limits-yy1_tutanaklimiti_pdh }| ) TO lt_message.
    ENDIF.

    " Kaydet
    IF lv_flag IS INITIAL.
      zcl_mm_int_gen=>get_instance( IMPORTING r_instance = DATA(ro_instance) ).
      lv_status = '1'.
      lv_statust = 'İşleniyor'.

      ro_instance->create_int(
        it_item              = lt_item
        iv_serviceentrysheet = lv_serviceentrysheet
      ).

      APPEND VALUE #( type = 'S' message = 'Veriler kayıt edildi.' ) TO lt_message.

      " Sadece kesinti tutarını hesapla
      lv_amount = REDUCE zmmd_mmpur_ses_item_netprice( INIT val TYPE zmmd_mmpur_ses_item_netprice
                    FOR wa IN lt_item WHERE ( record_type = 'K' )
                    NEXT val = val + wa-amount ).
    ENDIF.

    IF lv_status EQ '1'.
      lv_statust = 'İşleniyor'.
    ELSEIF lv_status EQ '2'.
      lv_statust = 'Kapatıldı'.
    ENDIF.

    /ui2/cl_json=>serialize( EXPORTING data = lt_message pretty_name = /ui2/cl_json=>pretty_mode-camel_case RECEIVING r_json = DATA(lv_res_json) ).
    APPEND INITIAL LINE TO lt_return ASSIGNING FIELD-SYMBOL(<fs_return>).
    <fs_return>-evjson  = lv_res_json.
    <fs_return>-status  = lv_status.
    <fs_return>-statust = lv_statust.
    <fs_return>-amount  = lv_amount.
    <fs_return>-filter  = space.
    io_response->set_data( lt_return ).
    IF io_request->is_total_numb_of_rec_requested(  ).
      io_response->set_total_number_of_records( lines( lt_return ) ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
