CLASS zcl_mm_hakedis_imalat_qry DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.



CLASS zcl_mm_hakedis_imalat_qry IMPLEMENTATION.


  METHOD if_rap_query_provider~select.
    TYPES: ty_wbs_id TYPE c LENGTH 24.
    TYPES: ty_matgrp TYPE c LENGTH 9.
    TYPES: BEGIN OF ty_mg_text,
             materialgroup     TYPE c LENGTH 9,
             materialgrouptext TYPE c LENGTH 40,
           END OF ty_mg_text.
    TYPES: BEGIN OF ty_wbs_text,
             wbselement  TYPE c LENGTH 24,
             description TYPE c LENGTH 40,
           END OF ty_wbs_text.
    TYPES: BEGIN OF ty_acct_wbs,
             purchaseorderitem      TYPE ebelp,
             wbselementinternalid_2 TYPE c LENGTH 24,
           END OF ty_acct_wbs.
    TYPES: BEGIN OF ty_wbs_map,
             wbselementinternalid TYPE c LENGTH 24,
             projectelement       TYPE c LENGTH 24,
             description          TYPE c LENGTH 40,
           END OF ty_wbs_map.

    DATA: lt_response TYPE TABLE OF zmmr_hakedis_det_imalat,
          ls_resp     TYPE zmmr_hakedis_det_imalat.

    DATA(lv_offset)    = io_request->get_paging( )->get_offset( ).
    DATA(lv_page_size) = io_request->get_paging( )->get_page_size( ).

    DATA lv_ses TYPE ebeln.  " Filtreden gelen "ServiceEntrySheet" artık HAKEDİŞ = PurchaseOrder
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

    " Hakediş (PO) → Sözleşme (Contract) bul. lv_po artık CONTRACT taşır.
    SELECT SINGLE yy1_purchasecontract_pdh
      FROM i_purchaseorderapi01
      WHERE purchaseorder = @lv_ses
      INTO @DATA(lv_po).

    IF lv_po IS INITIAL.
      io_response->set_total_number_of_records( 0 ).
      io_response->set_data( lt_response ).
      RETURN.
    ENDIF.

    " Sözleşme para birimi.
    SELECT SINGLE documentcurrency
      FROM i_purchasecontractapi01
      WHERE purchasecontract = @lv_po
      INTO @DATA(lv_currency).

    " ÖNCEKİ: aynı sözleşmenin, GÜNCEL hakediş HARİÇ, onaylı PO'larının kalem miktar/tutar
    " toplamı; SÖZLEŞME KALEMİ (purchasecontractitem) bazında grupla.
    SELECT po_item~purchasecontractitem AS purchaseorderitem,   " 🔶 PO kalemindeki sözleşme kalemi referansı
    SUM( CASE po_item~isreturnsitem WHEN 'X' THEN po_item~orderquantity * -1
                                 ELSE po_item~orderquantity END ) AS total_qty,
    SUM( CASE po_item~isreturnsitem WHEN 'X' THEN po_item~netamount * -1
                                 ELSE po_item~netamount END ) AS total_amt
      FROM i_purchaseorderapi01   AS po
      INNER JOIN i_purchaseorderitemapi01 AS po_item
        ON po~purchaseorder = po_item~purchaseorder
      WHERE po~yy1_purchasecontract_pdh    = @lv_po
        AND po~purchaseorder              LT @lv_ses
        AND po~purchasingprocessingstatus  = '05'
      GROUP BY po_item~purchasecontractitem
      INTO TABLE @DATA(lt_onceki).

    " ŞİMDİKİ: bu hakedişin (PO) kalemleri; sözleşme kalemi bazında grupla.
    SELECT po_item~purchasecontractitem AS purchaseorderitem,
    SUM( CASE po_item~isreturnsitem WHEN 'X' THEN po_item~orderquantity * -1
                                 ELSE po_item~orderquantity END ) AS total_qty,
    SUM( CASE po_item~isreturnsitem WHEN 'X' THEN po_item~netamount * -1
                                 ELSE po_item~netamount END ) AS total_amt
      FROM i_purchaseorderitemapi01 AS po_item
      WHERE po_item~purchaseorder = @lv_ses
      GROUP BY po_item~purchasecontractitem
      INTO TABLE @DATA(lt_simdiki).

    " BAZ SATIRLAR: sözleşme kalemleri. Alan adları alt bloklardaki mantık aynen çalışsın
    " diye eski isimlerle AS edildi (purchaseorderitem = sözleşme kalemi no).
    SELECT purchasecontractitem      AS purchaseorderitem,
           material                  AS material,
           targetquantity           AS orderquantity,              " sözleşme hedef miktarı
           orderquantityunit         AS purchaseorderquantityunit,
           contractnetpriceamount    AS netpriceamount,            " Birim Fiyat
           targetamount              AS contractamount,            " Kalem Tutarı (sözleşme kalemi TargetAmount)
           materialgroup            AS materialgroup,
           purchasecontractitemtext  AS purchaseorderitemtext
      FROM i_purchasecontractitemapi01
      WHERE purchasecontract = @lv_po
      INTO TABLE @DATA(lt_po_items).

    " WBS: hesap ataması sözleşmede değil, HAKEDİŞ (PO) kaleminde tutulur. Güncel hakedişin
    " PO hesap atamasını al, PO kalemindeki sözleşme kalemi referansına (purchasecontractitem) bağla.
    DATA lt_acct_wbs TYPE STANDARD TABLE OF ty_acct_wbs WITH EMPTY KEY.
    SELECT po_item~purchasecontractitem AS purchaseorderitem,
           aa~wbselementinternalid_2
      FROM i_purchaseorderitemapi01 AS po_item
      INNER JOIN i_purordaccountassignmentapi01 AS aa
        ON  po_item~purchaseorder     = aa~purchaseorder
        AND po_item~purchaseorderitem = aa~purchaseorderitem
      WHERE po_item~purchaseorder = @lv_ses
        AND aa~wbselementinternalid_2 IS NOT INITIAL
      INTO TABLE @lt_acct_wbs.                           "#EC CI_NOAUTH
    SORT lt_acct_wbs BY purchaseorderitem.
    DELETE ADJACENT DUPLICATES FROM lt_acct_wbs COMPARING purchaseorderitem.

    DATA lt_mat_r TYPE RANGE OF matnr.
    LOOP AT lt_po_items ASSIGNING FIELD-SYMBOL(<itm>).
      IF <itm>-material IS NOT INITIAL.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <itm>-material ) TO lt_mat_r.
      ENDIF.
    ENDLOOP.
    SORT lt_mat_r BY low. DELETE ADJACENT DUPLICATES FROM lt_mat_r COMPARING low.

    DATA lt_texts TYPE TABLE OF i_productdescription WITH EMPTY KEY.
    IF lt_mat_r IS NOT INITIAL.
      SELECT product, productdescription
        FROM i_productdescription
        WHERE product  IN @lt_mat_r
          AND language = 'T'
        INTO TABLE @lt_texts.
    ENDIF.

    DATA lt_mg_r TYPE RANGE OF ty_matgrp.
    LOOP AT lt_po_items ASSIGNING FIELD-SYMBOL(<mg>).
      IF <mg>-materialgroup IS NOT INITIAL.
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <mg>-materialgroup ) TO lt_mg_r.
      ENDIF.
    ENDLOOP.
    SORT lt_mg_r BY low. DELETE ADJACENT DUPLICATES FROM lt_mg_r COMPARING low.

    DATA lt_mg_texts TYPE STANDARD TABLE OF ty_mg_text WITH EMPTY KEY.
    IF lt_mg_r IS NOT INITIAL.
      SELECT productgroup AS materialgroup,
             productgrouptext AS materialgrouptext
        FROM i_productgrouptext_2
        WHERE productgroup IN @lt_mg_r
          AND language = 'T'
        INTO TABLE @lt_mg_texts.                         "#EC CI_NOAUTH
    ENDIF.

    " WBS: internal ID → external ID + text çözümleme
    DATA lt_wbs_map TYPE STANDARD TABLE OF ty_wbs_map WITH EMPTY KEY.
    IF lt_acct_wbs IS NOT INITIAL.
      DATA lr_wbs_int TYPE RANGE OF ty_wbs_id.
      LOOP AT lt_acct_wbs ASSIGNING FIELD-SYMBOL(<aw2>).
        APPEND VALUE #( sign = 'I' option = 'EQ' low = <aw2>-wbselementinternalid_2 ) TO lr_wbs_int.
      ENDLOOP.

      SELECT proj~wbselementinternalid,
             proj~projectelement,
             proj~projectelementdescription AS description
        FROM i_enterpriseprojectelement AS proj
        WHERE proj~wbselementinternalid IN @lr_wbs_int
        INTO TABLE @lt_wbs_map.                          "#EC CI_NOAUTH
    ENDIF.

    LOOP AT lt_po_items ASSIGNING FIELD-SYMBOL(<po_itm>).
      CLEAR ls_resp.
      ls_resp-serviceentrysheet     = lv_ses.
      ls_resp-purchaseorderitem     = <po_itm>-purchaseorderitem.
      ls_resp-material              = <po_itm>-material.
      ls_resp-orderquantity         = <po_itm>-orderquantity.
      ls_resp-orderquantityunit     = <po_itm>-purchaseorderquantityunit.
      ls_resp-netpriceamount        = <po_itm>-netpriceamount.
      " Kalem Tutarı: sözleşme kalemi TargetAmount; boşsa miktar × birim fiyat'a düş
      ls_resp-contractamount        = COND #( WHEN <po_itm>-contractamount IS NOT INITIAL
                                              THEN <po_itm>-contractamount
                                              ELSE <po_itm>-orderquantity * <po_itm>-netpriceamount ).
      ls_resp-documentcurrency      = lv_currency.
      ls_resp-productgroup          = <po_itm>-materialgroup.

      " WBS from account assignment (internal → external)
      READ TABLE lt_acct_wbs INTO DATA(ls_aw)
        WITH KEY purchaseorderitem = <po_itm>-purchaseorderitem.
      IF sy-subrc = 0.
        READ TABLE lt_wbs_map INTO DATA(ls_wm)
          WITH KEY wbselementinternalid = ls_aw-wbselementinternalid_2.
        IF sy-subrc = 0.
          ls_resp-wbselementexternalid = ls_wm-projectelement.
          ls_resp-wbselementtext       = ls_wm-description.
        ENDIF.
      ENDIF.

      READ TABLE lt_texts INTO DATA(ls_txt)
        WITH KEY product = <po_itm>-material.
      IF sy-subrc = 0.
        ls_resp-materialtext = ls_txt-productdescription.
      ENDIF.

      ls_resp-materiallongtext = <po_itm>-purchaseorderitemtext.

      READ TABLE lt_mg_texts INTO DATA(ls_mgt)
        WITH KEY materialgroup = <po_itm>-materialgroup.
      IF sy-subrc = 0.
        ls_resp-productgrouptext = ls_mgt-materialgrouptext.
      ENDIF.

      READ TABLE lt_onceki INTO DATA(ls_onc)
        WITH KEY purchaseorderitem = <po_itm>-purchaseorderitem.
      IF sy-subrc = 0.
        ls_resp-prevquantity = ls_onc-total_qty.
        ls_resp-prevamount   = ls_onc-total_amt.
      ENDIF.

      READ TABLE lt_simdiki INTO DATA(ls_sim)
        WITH KEY purchaseorderitem = <po_itm>-purchaseorderitem.
      IF sy-subrc = 0.
        ls_resp-currquantity = ls_sim-total_qty.
        ls_resp-curramount   = ls_sim-total_amt.
      ENDIF.

      ls_resp-totalquantity = ls_resp-prevquantity + ls_resp-currquantity.
      ls_resp-totalamount   = ls_resp-prevamount   + ls_resp-curramount.

      IF <po_itm>-orderquantity <> 0.
        ls_resp-prevpercent     = ls_resp-prevquantity  / <po_itm>-orderquantity * 100.
        ls_resp-currpercent     = ls_resp-currquantity  / <po_itm>-orderquantity * 100.
        ls_resp-progresspercent = ls_resp-totalquantity / <po_itm>-orderquantity * 100.
      ENDIF.

      APPEND ls_resp TO lt_response.
    ENDLOOP.

    io_response->set_total_number_of_records( lines( lt_response ) ).

    IF lv_page_size > 0.
      DATA(lv_max) = lv_offset + lv_page_size.
      IF lv_max > lines( lt_response ).
        lv_max = lines( lt_response ).
      ENDIF.

      DATA lt_page TYPE TABLE OF zmmr_hakedis_det_imalat.
      LOOP AT lt_response INTO DATA(ls_pg) FROM ( lv_offset + 1 ) TO lv_max.
        APPEND ls_pg TO lt_page.
      ENDLOOP.

      io_response->set_data( lt_page ).
    ELSE.
      io_response->set_data( lt_response ).
    ENDIF.

  ENDMETHOD.
ENDCLASS.
