CLASS zcl_mm_hakedis_cikti_qry DEFINITION
  PUBLIC FINAL CREATE PUBLIC.
  PUBLIC SECTION.
    INTERFACES if_rap_query_provider.
ENDCLASS.



CLASS ZCL_MM_HAKEDIS_CIKTI_QRY IMPLEMENTATION.


  METHOD if_rap_query_provider~select.
* yazma testi - Claude Code, 2026-09-03 (DAP_DEV)
    DATA: lt_response TYPE TABLE OF zmmr_hakedis_cikti_cds,
          ls_resp     TYPE zmmr_hakedis_cikti_cds.

    DATA(lv_offset)    = io_request->get_paging( )->get_offset( ).
    DATA(lv_page_size) = io_request->get_paging( )->get_page_size( ).

    TRY.
        DATA(lt_filters) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range cx_root.       "#EC NO_HANDLER
    ENDTRY.

*  ESKİ (SES=hakediş, PO=sözleşme):
*    SELECT ses~serviceentrysheet, ses~purchaseorder, po~supplier, po~companycode,
*           po~purchaseorderdate, po~documentcurrency, po~yy1_szlemetipi_pdh,
*           po~yy1_anagrup_pdh, po~yy1_sozbastar_pdh, po~yy1_sozbittar_pdh,
*           ses~serviceentrysheetname, ses~creationdatetime, ses~postingdate, ses~approvalstatus
*      FROM i_serviceentrysheetapi01 AS ses
*      LEFT JOIN i_purchaseorderapi01 AS po ON ses~purchaseorder = po~purchaseorder
*      WHERE po~purchaseordertype = 'Z004' AND ses~isdeleted = ' '
*      INTO TABLE @DATA(lt_raw).
*
*  YENİ: PO = Hakediş, PurchaseContract = Sözleşme.
*  Response yapısı (CDS) alan adları korunsun diye eski isimlerle "AS" edildi:
*    serviceentrysheet -> Hakediş No (artık PurchaseOrder)
*    purchaseorder     -> Sözleşme No (artık PurchaseContract)
    SELECT po~purchaseorder                  AS serviceentrysheet,   " Hakediş No
           po~yy1_purchasecontract_pdh       AS purchaseorder,       " Sözleşme No (= con~purchasecontract)
           con~supplier                      AS supplier,
           con~companycode                   AS companycode,
           con~creationdate                  AS purchaseorderdate,   " Sözleşme Tarihi
           con~documentcurrency              AS documentcurrency,
           con~yy1_szlemetipi_pdh            AS yy1_szlemetipi_pdh,
           con~yy1_anagrup_pdh               AS yy1_anagrup_pdh,
           con~validitystartdate             AS yy1_sozbastar_pdh,   " Sözleşme Başlangıç Tarihi
           con~validityenddate               AS yy1_sozbittar_pdh,   " Sözleşme Bitiş Tarihi
           con~purchasecontracttargetamount  AS totalcontractamount, " Toplam Sözleşme Tutarı (🔶 S6: alternatif = I_PurchaseContractItemAPI01 kalem toplamı)
           po~creationdate                   AS creationdate,        " Hakediş Düzenlenme Tarihi (DATS)
           po~purchaseorderdate              AS postingdate,         " Hakediş Kayıt Tarihi
           po~purchasingprocessingstatus     AS approvalstatus,      " Hakediş Onay Durumu
           po~yy1_hakedisadi_pdh             AS hakedisadi
      FROM i_purchaseorderapi01 AS po
      LEFT JOIN i_purchasecontractapi01 AS con
        ON po~yy1_purchasecontract_pdh = con~purchasecontract
      WHERE po~purchasingdocumentdeletioncode = ' '
        AND po~PurchaseOrderType     = 'Z004'
        AND con~PurchaseContractType = 'Z004'
      INTO TABLE @DATA(lt_raw).                          "#EC CI_NOAUTH

    LOOP AT lt_filters INTO DATA(ls_filter).
      DATA(lv_fname) = ls_filter-name.
      TRANSLATE lv_fname TO UPPER CASE.
      IF lines( ls_filter-range ) = 0. CONTINUE. ENDIF.
      CASE lv_fname.
        WHEN 'PURCHASEORDER'.     DELETE lt_raw WHERE purchaseorder      NOT IN ls_filter-range.
        WHEN 'PURCHASEORDERTYPE'. DELETE lt_raw WHERE yy1_szlemetipi_pdh NOT IN ls_filter-range.
        WHEN 'YY1_ANAGRUP_PDH'.   DELETE lt_raw WHERE yy1_anagrup_pdh    NOT IN ls_filter-range.
        WHEN 'COMPANYCODE'.       DELETE lt_raw WHERE companycode        NOT IN ls_filter-range.
        WHEN 'SUPPLIER'.          DELETE lt_raw WHERE supplier           NOT IN ls_filter-range.
        WHEN 'SERVICEENTRYSHEET'. DELETE lt_raw WHERE serviceentrysheet  NOT IN ls_filter-range.
      ENDCASE.
    ENDLOOP.

    IF lt_raw IS INITIAL.
      io_response->set_total_number_of_records( 0 ).
      io_response->set_data( lt_response ).
      RETURN.
    ENDIF.

    DATA lr_po       TYPE RANGE OF i_purchasecontractapi01-purchasecontract. " sözleşme (Contract) — raw-purchaseorder taşır
    DATA lr_ses      TYPE RANGE OF i_purchaseorderapi01-purchaseorder.       " hakediş (PO) — raw-serviceentrysheet taşır
    DATA lr_supplier TYPE RANGE OF i_supplier-supplier.

    LOOP AT lt_raw INTO DATA(ls_r).
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_r-purchaseorder     ) TO lr_po.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_r-serviceentrysheet ) TO lr_ses.
      APPEND VALUE #( sign = 'I' option = 'EQ' low = ls_r-supplier          ) TO lr_supplier.
    ENDLOOP.
    SORT lr_po       BY low. DELETE ADJACENT DUPLICATES FROM lr_po       COMPARING low.
    SORT lr_ses      BY low. DELETE ADJACENT DUPLICATES FROM lr_ses      COMPARING low.
    SORT lr_supplier BY low. DELETE ADJACENT DUPLICATES FROM lr_supplier COMPARING low.

    SELECT supplier, suppliername
      FROM i_supplier
      WHERE supplier IN @lr_supplier
      INTO TABLE @DATA(lt_suppliers).                    "#EC CI_NOAUTH

    SELECT companycode, companycodename
      FROM i_companycode
      INTO TABLE @DATA(lt_companies).    "#EC CI_NOAUTH "#EC CI_NOWHERE


    " ===== Vergi kodu → oran (KDV DAHİL hesabı için) =====
    SELECT rate~taxcode, rate~conditionrateratio AS ratio
      FROM i_taxcodetext AS txt
      INNER JOIN i_taxcoderate AS rate
        ON  rate~taxcode                 = txt~taxcode
        AND rate~taxcalculationprocedure = txt~taxcalculationprocedure
      WHERE txt~language = 'T'
        AND rate~cndnrecordvaliditystartdate <= @sy-datum
        AND rate~cndnrecordvalidityenddate   >= @sy-datum
      INTO TABLE @DATA(lt_taxrate).                       "#EC CI_NOAUTH
    SORT lt_taxrate BY taxcode.
    DELETE ADJACENT DUPLICATES FROM lt_taxrate COMPARING taxcode.

    " Hakediş Tutarı: PO kalem toplamları — VERGİ KODU bazında (hariç + KDV dahil).
    SELECT purchaseorder, taxcode, SUM( CASE isreturnsitem WHEN 'X' THEN netamount * -1
                                                                    ELSE netamount END  ) AS total_amount
      FROM i_purchaseorderitemapi01
      WHERE purchaseorder IN @lr_ses
      GROUP BY purchaseorder, taxcode
      INTO TABLE @DATA(lt_ses_bytax).                     "#EC CI_NOAUTH

    " Hakediş bazlı kesinti — log.serviceentrysheet artık PO taşıyor
    " Yalnızca KESİNTİ kayıtları (record_type='K'); tutanak ('T')
    SELECT serviceentrysheet, SUM( amount ) AS total_amount, SUM( amountwithtax ) AS total_amount_tax
      FROM zmmt_inter_log
      WHERE serviceentrysheet IN @lr_ses
        AND record_type = 'K'
      GROUP BY serviceentrysheet
      INTO TABLE @DATA(lt_int_ses).                      "#EC CI_NOAUTH

    " Sözleşme bazlı toplam kesinti — log.purchaseorder artık Contract taşıyor. lr_po artık Contract taşıyor.
    SELECT purchaseorder, SUM( amount ) AS total_amount
      FROM zmmt_inter_log
      WHERE purchaseorder IN @lr_po
        AND record_type = 'K'
      GROUP BY purchaseorder
      INTO TABLE @DATA(lt_int_po).                       "#EC CI_NOAUTH

    SELECT serviceentrysheet, statu
      FROM zmmt_inter_log
      WHERE serviceentrysheet IN @lr_ses
      INTO TABLE @DATA(lt_int_statu).                    "#EC CI_NOAUTH

    " Önceki (onaylı) hakediş toplamı: onaylı PO'ların kalem toplamı, Contract bazında grupla.
    " (Eski: onaylı SES'ler '30', PO bazında.)
    SELECT po~yy1_purchasecontract_pdh AS purchasecontract,
           po~purchaseorder AS purchaseorder,
           item~taxcode AS taxcode,
           SUM( CASE item~isreturnsitem WHEN 'X' THEN item~netamount * -1
                                                 ELSE item~netamount END ) AS total_amount
      FROM i_purchaseorderapi01 AS po
      INNER JOIN i_purchaseorderitemapi01 AS item
        ON po~purchaseorder = item~purchaseorder
      WHERE po~purchasingprocessingstatus = '05'
        AND po~yy1_purchasecontract_pdh IN @lr_po
      GROUP BY po~yy1_purchasecontract_pdh, po~purchaseorder, item~taxcode
      INTO TABLE @DATA(lt_prev_ses).                     "#EC CI_NOAUTH

    " Sözleşme kalemleri: VERGİ KODU bazında hedef tutar (Toplam Sözleşme Tutarı KDV dahil brütleştirmesi için).
    SELECT purchasecontract, taxcode, SUM( targetamount ) AS total_amount
      FROM i_purchasecontractitemapi01
      WHERE purchasecontract IN @lr_po
      GROUP BY purchasecontract, taxcode
      INTO TABLE @DATA(lt_con_bytax).                     "#EC CI_NOAUTH

    " Tutanaklı işler toplamı: tutanak (T) kayıtlarının NET tutarı = amount (KDV hariç).
    SELECT serviceentrysheet, SUM( amount ) AS total_net, SUM( amountwithtax ) AS total_tax
      FROM zmmt_inter_log
      WHERE serviceentrysheet IN @lr_ses
        AND record_type = 'T'
      GROUP BY serviceentrysheet
      INTO TABLE @DATA(lt_tutanak).                      "#EC CI_NOAUTH

    " Kesinti türü kırılımı (IntK01–K26): yalnızca kesinti kayıtları ('K').
    SELECT serviceentrysheet, interruptiontype, SUM( amount ) AS total_net
      FROM zmmt_inter_log
      WHERE serviceentrysheet IN @lr_ses
        AND record_type = 'K'
      GROUP BY serviceentrysheet, interruptiontype
      INTO TABLE @DATA(lt_int_by_type).                  "#EC CI_NOAUTH

    LOOP AT lt_raw INTO DATA(ls_raw).
      CLEAR ls_resp.

      ls_resp-serviceentrysheet     = ls_raw-serviceentrysheet.   " Hakediş No (PO)
      ls_resp-purchaseorder         = ls_raw-purchaseorder.       " Sözleşme No (Contract)
      ls_resp-supplier              = ls_raw-supplier.
      ls_resp-companycode           = ls_raw-companycode.
      ls_resp-documentcurrency      = ls_raw-documentcurrency.
      ls_resp-serviceentrysheetname = ls_raw-hakedisadi.          " Hakediş adı
      ls_resp-purchaseorderdate     = ls_raw-purchaseorderdate.   " Sözleşme Tarihi (Contract-CreationDate)
      ls_resp-postingdate           = ls_raw-postingdate.         " Hakediş Kayıt Tarihi (PO-PurchaseOrderDate)
      ls_resp-approvalstatus        = ls_raw-approvalstatus.      " PO-PurchasingProcessingStatus
      ls_resp-purchaseordertype     = ls_raw-yy1_szlemetipi_pdh.
      ls_resp-yy1_anagrup_pdh       = ls_raw-yy1_anagrup_pdh.
      ls_resp-yy1_sozbastar         = ls_raw-yy1_sozbastar_pdh.   " Contract-ValidityStartDate
      ls_resp-yy1_sozbittar         = ls_raw-yy1_sozbittar_pdh.   " Contract-ValidityEndDate
      ls_resp-creationdate          = ls_raw-creationdate.

      CASE ls_raw-yy1_szlemetipi_pdh.
        WHEN '01'. ls_resp-purchaseordertypetxt = 'TASARIM/DANIŞMANLIK : MÜE' ##NO_TEXT.
        WHEN '02'. ls_resp-purchaseordertypetxt = 'TASARIM/DANIŞMANLIK : DAN' ##NO_TEXT.
        WHEN '03'. ls_resp-purchaseordertypetxt = 'UYGULAMA DİREKT : MALZEME' ##NO_TEXT.
        WHEN '04'. ls_resp-purchaseordertypetxt = 'UYGULAMA DİREKT : MALZEME' ##NO_TEXT.
        WHEN '05'. ls_resp-purchaseordertypetxt = 'UYGULAMA DİREKT : İŞÇİLİK' ##NO_TEXT.
        WHEN '06'. ls_resp-purchaseordertypetxt = 'UYGULAMA DİREKT : MAKİNE-' ##NO_TEXT.
        WHEN '07'. ls_resp-purchaseordertypetxt = 'UYGULAMA DİREKT : MAKİNE-' ##NO_TEXT.
      ENDCASE.

      CASE ls_raw-yy1_anagrup_pdh.
        WHEN '1'. ls_resp-yy1_anagrup_pdht = 'ANA SÖZLEŞME' ##NO_TEXT.
        WHEN '2'. ls_resp-yy1_anagrup_pdht = 'EK MUTABAKAT (YENİ BİRİM FİYAT)' ##NO_TEXT.
        WHEN '3'. ls_resp-yy1_anagrup_pdht = 'EK MUTABAKAT (FİYAT FARKI)' ##NO_TEXT.
        WHEN '4'. ls_resp-yy1_anagrup_pdht = 'EK MUTABAKAT (YENİ B.FİYAT + FİYAT FARKI' ##NO_TEXT.
        WHEN '5'. ls_resp-yy1_anagrup_pdht = 'FESİH PROTOKOLÜ' ##NO_TEXT.
        WHEN '6'. ls_resp-yy1_anagrup_pdht = 'ALT YÜKLENİCİ TAAHHÜTNAMESİ' ##NO_TEXT.
        WHEN '7'. ls_resp-yy1_anagrup_pdht = 'GARANTÖRLÜK SÖZLEŞME' ##NO_TEXT.
      ENDCASE.

      READ TABLE lt_suppliers INTO DATA(ls_sup) WITH KEY supplier = ls_raw-supplier.
      IF sy-subrc = 0. ls_resp-suppliername = ls_sup-suppliername. ENDIF.

      READ TABLE lt_companies INTO DATA(ls_cc) WITH KEY companycode = ls_raw-companycode.
      IF sy-subrc = 0. ls_resp-companycodename = ls_cc-companycodename. ENDIF.

      CASE ls_raw-approvalstatus.
        WHEN '01'. ls_resp-approvalstatustext = 'Taslak aşamasında' ##NO_TEXT.
          ls_resp-approvalstatuscriticality = 0.
        WHEN '02'. ls_resp-approvalstatustext = 'Onayda' ##NO_TEXT.
          ls_resp-approvalstatuscriticality = 2.
        WHEN '03'. ls_resp-approvalstatustext = 'Onay Tamamlanmadı' ##NO_TEXT.
          ls_resp-approvalstatuscriticality = 2.
        WHEN '04'. ls_resp-approvalstatustext = 'Reddedildi' ##NO_TEXT.
          ls_resp-approvalstatuscriticality = 1.
        WHEN '05'. ls_resp-approvalstatustext = 'Onaylandı' ##NO_TEXT.
          ls_resp-approvalstatuscriticality = 3.
      ENDCASE.

      " Toplam Sözleşme Tutarı: Contract hedef tutarı (ana SELECT'te getirildi)
      "ls_resp-totalcontractamount = ls_raw-totalcontractamount.

      " Hakediş Tutarı (hariç) + KDV DAHİL: PO kalemleri VERGİ KODU bazında; oran = lt_taxrate (I_TaxCodeRate).
      DATA ls_taxrate LIKE LINE OF lt_taxrate.
      DATA lv_factor  TYPE decfloat34.
      LOOP AT lt_ses_bytax INTO DATA(ls_sbt) WHERE purchaseorder = ls_raw-serviceentrysheet.
        CLEAR ls_taxrate.
        READ TABLE lt_taxrate INTO ls_taxrate WITH KEY taxcode = ls_sbt-taxcode.
        lv_factor = 1 + ls_taxrate-ratio / 100.   " bulunamazsa ratio=0 → faktör=1
        ls_resp-sesamount    = ls_resp-sesamount    + ls_sbt-total_amount.
        ls_resp-sesamounttax = ls_resp-sesamounttax + ls_sbt-total_amount * lv_factor.
      ENDLOOP.

      " Hakediş bazlı kesinti (log.serviceentrysheet = PO) — hariç + dahil
      READ TABLE lt_int_ses INTO DATA(ls_int) WITH KEY serviceentrysheet = ls_raw-serviceentrysheet.
      IF sy-subrc = 0.
        ls_resp-totalinterruptionamount    = ls_int-total_amount.
        ls_resp-totalinterruptionamounttax = ls_int-total_amount_tax.
      ENDIF.

      " Sözleşme bazlı toplam kesinti (log.purchaseorder = Contract)
      READ TABLE lt_int_po INTO DATA(ls_intpo) WITH KEY purchaseorder = ls_raw-purchaseorder.
      IF sy-subrc = 0. ls_resp-alldeductiontotal = ls_intpo-total_amount. ENDIF.

      " Önceki (onaylı) hakediş imalat toplamı — Contract bazlı (hariç + KDV DAHİL)
      LOOP AT lt_prev_ses INTO DATA(ls_prev)
          WHERE purchasecontract = ls_raw-purchaseorder
            AND purchaseorder    LT ls_raw-serviceentrysheet.
        CLEAR ls_taxrate.
        READ TABLE lt_taxrate INTO ls_taxrate WITH KEY taxcode = ls_prev-taxcode.
        lv_factor = 1 + ls_taxrate-ratio / 100.
        ls_resp-prevsestotal    = ls_resp-prevsestotal    + ls_prev-total_amount.
        ls_resp-prevsestotaltax = ls_resp-prevsestotaltax + ls_prev-total_amount * lv_factor.
      ENDLOOP.

      ls_resp-grandsestotal    = ls_resp-prevsestotal    + ls_resp-sesamount.
      ls_resp-grandsestotaltax = ls_resp-prevsestotaltax + ls_resp-sesamounttax.

      READ TABLE lt_tutanak INTO DATA(ls_tut) WITH KEY serviceentrysheet = ls_raw-serviceentrysheet.
      IF sy-subrc = 0.
        ls_resp-tutanakamount    = ls_tut-total_net.
        ls_resp-tutanakamounttax = ls_tut-total_tax.
      ENDIF.

      ls_resp-odenecektutar = ls_resp-sesamount + ls_resp-tutanakamount - ls_resp-totalinterruptionamount.

      " ===== KDV DAHİL
      DATA lv_con_haric TYPE decfloat34.
      DATA lv_con_dahil TYPE decfloat34.
      CLEAR: lv_con_haric, lv_con_dahil.
      LOOP AT lt_con_bytax INTO DATA(ls_cbt) WHERE purchasecontract = ls_raw-purchaseorder.
        CLEAR ls_taxrate.
        READ TABLE lt_taxrate INTO ls_taxrate WITH KEY taxcode = ls_cbt-taxcode.
        lv_factor    = 1 + ls_taxrate-ratio / 100.
        lv_con_haric = lv_con_haric + ls_cbt-total_amount.
        lv_con_dahil = lv_con_dahil + ls_cbt-total_amount * lv_factor.
        ls_resp-totalcontractamount = ls_resp-totalcontractamount + ls_cbt-total_amount.
      ENDLOOP.
      IF lv_con_haric <> 0.
        ls_resp-totalcontractamounttax = ls_resp-totalcontractamount * ( lv_con_dahil / lv_con_haric ).
      ELSE.
        ls_resp-totalcontractamounttax = ls_resp-totalcontractamount.
      ENDIF.

      " Ödenecek (dahil) = imalat(dahil) + tutanak(dahil) − kesinti(dahil)
      ls_resp-odenecektutartax = ls_resp-sesamounttax + ls_resp-tutanakamounttax - ls_resp-totalinterruptionamounttax.

      LOOP AT lt_int_by_type INTO DATA(ls_ibt)
        WHERE serviceentrysheet = ls_raw-serviceentrysheet.
        CASE ls_ibt-interruptiontype.
          WHEN 'K01'. ls_resp-intk01 = ls_ibt-total_net.
          WHEN 'K02'. ls_resp-intk02 = ls_ibt-total_net.
          WHEN 'K03'. ls_resp-intk03 = ls_ibt-total_net.
          WHEN 'K04'. ls_resp-intk04 = ls_ibt-total_net.
          WHEN 'K05'. ls_resp-intk05 = ls_ibt-total_net.
          WHEN 'K06'. ls_resp-intk06 = ls_ibt-total_net.
          WHEN 'K07'. ls_resp-intk07 = ls_ibt-total_net.
          WHEN 'K08'. ls_resp-intk08 = ls_ibt-total_net.
          WHEN 'K09'. ls_resp-intk09 = ls_ibt-total_net.
          WHEN 'K10'. ls_resp-intk10 = ls_ibt-total_net.
          WHEN 'K11'. ls_resp-intk11 = ls_ibt-total_net.
          WHEN 'K12'. ls_resp-intk12 = ls_ibt-total_net.
          WHEN 'K13'. ls_resp-intk13 = ls_ibt-total_net.
          WHEN 'K14'. ls_resp-intk14 = ls_ibt-total_net.
          WHEN 'K15'. ls_resp-intk15 = ls_ibt-total_net.
          WHEN 'K16'. ls_resp-intk16 = ls_ibt-total_net.
          WHEN 'K17'. ls_resp-intk17 = ls_ibt-total_net.
          WHEN 'K18'. ls_resp-intk18 = ls_ibt-total_net.
          WHEN 'K19'. ls_resp-intk19 = ls_ibt-total_net.
          WHEN 'K20'. ls_resp-intk20 = ls_ibt-total_net.
          WHEN 'K21'. ls_resp-intk21 = ls_ibt-total_net.
          WHEN 'K22'. ls_resp-intk22 = ls_ibt-total_net.
          WHEN 'K23'. ls_resp-intk23 = ls_ibt-total_net.
          WHEN 'K24'. ls_resp-intk24 = ls_ibt-total_net.
          WHEN 'K25'. ls_resp-intk25 = ls_ibt-total_net.
          WHEN 'K26'. ls_resp-intk26 = ls_ibt-total_net.
        ENDCASE.
      ENDLOOP.

      DATA(lv_has_record) = abap_false.
      DATA(lv_has_saved)  = abap_false.
      LOOP AT lt_int_statu INTO DATA(ls_is) WHERE serviceentrysheet = ls_raw-serviceentrysheet.
        lv_has_record = abap_true.
        IF ls_is-statu = '2'. lv_has_saved = abap_true. ENDIF.
      ENDLOOP.

      IF lv_has_record = abap_false.
        ls_resp-intstatu = ' '. ls_resp-intstatutext = 'Kesinti girişi yok' ##NO_TEXT.
        ls_resp-intstatucriticality = 0.
      ELSEIF lv_has_saved = abap_true.
        ls_resp-intstatu = '2'. ls_resp-intstatutext = 'Kesinti girişi tamamlanmış' ##NO_TEXT.
        ls_resp-intstatucriticality = 3.
      ELSE.
        ls_resp-intstatu = '1'. ls_resp-intstatutext = 'Kesinti girişi devam ediyor' ##NO_TEXT.
        ls_resp-intstatucriticality = 2.
      ENDIF.

      DATA(lv_skip) = abap_false.
      LOOP AT lt_filters INTO DATA(ls_df).
        DATA(lv_dfname) = ls_df-name.
        TRANSLATE lv_dfname TO UPPER CASE.
        IF lines( ls_df-range ) = 0. CONTINUE. ENDIF.
        CASE lv_dfname.
          WHEN 'CREATIONDATE'.       IF ls_resp-creationdate       NOT IN ls_df-range. lv_skip = abap_true. ENDIF.
          WHEN 'POSTINGDATE'.        IF ls_resp-postingdate        NOT IN ls_df-range. lv_skip = abap_true. ENDIF.
          WHEN 'APPROVALSTATUSTEXT'. IF ls_resp-approvalstatustext NOT IN ls_df-range. lv_skip = abap_true. ENDIF.
          WHEN 'INTSTATUTEXT'.       IF ls_resp-intstatutext       NOT IN ls_df-range. lv_skip = abap_true. ENDIF.
        ENDCASE.
      ENDLOOP.
      IF lv_skip = abap_true. CONTINUE. ENDIF.

      APPEND ls_resp TO lt_response.
    ENDLOOP.

    io_response->set_total_number_of_records( lines( lt_response ) ).

    IF lv_page_size > 0.
      DATA(lv_max) = lv_offset + lv_page_size.
      IF lv_max > lines( lt_response ). lv_max = lines( lt_response ). ENDIF.
      DATA lt_page TYPE TABLE OF zmmr_hakedis_cikti_cds.
      LOOP AT lt_response INTO DATA(ls_pg) FROM ( lv_offset + 1 ) TO lv_max.
        APPEND ls_pg TO lt_page.
      ENDLOOP.
      io_response->set_data( lt_page ).
    ELSE.
      io_response->set_data( lt_response ).
    ENDIF.

  ENDMETHOD.
ENDCLASS.
