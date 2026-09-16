CLASS zcl_mm_interruptionlist DEFINITION
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



CLASS ZCL_MM_INTERRUPTIONLIST IMPLEMENTATION.


  METHOD handle_paging.
    DATA(offset) = i_io_request->get_paging(  )->get_offset( ).
    DATA(page_size) = i_io_request->get_paging(  )->get_page_size(  ).
    DATA(max_rows) = COND #( WHEN page_size = if_rap_query_paging=>page_size_unlimited THEN 0 ELSE page_size ).
  ENDMETHOD.


  METHOD if_rap_query_provider~select.


    DATA: ls_request       TYPE  zmms_interruption_request,
          lr_supplier      TYPE RANGE OF lifnr,
          lr_plant         TYPE RANGE OF werks_d,
          lr_purchaseorder TYPE RANGE OF ebeln,

          lt_response      TYPE zmmtt_interruptionlist,
          lt_return        TYPE STANDARD TABLE OF zmmr_interruptionlist.
    FIELD-SYMBOLS: <fs_rspn>      TYPE zmms_interruptionlist.
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

    IF ls_request-supplier IS NOT INITIAL.
      LOOP AT ls_request-supplier INTO DATA(ls_supplier).
        APPEND INITIAL LINE TO lr_supplier ASSIGNING FIELD-SYMBOL(<fs_supplier>).
        <fs_supplier>-sign   = 'I'.
        <fs_supplier>-option = 'EQ'.
        <fs_supplier>-low    = |{ ls_supplier-supplier  ALPHA = IN }|. .
      ENDLOOP.
    ENDIF.

    IF ls_request-purchaseorder IS NOT INITIAL.
      LOOP AT ls_request-purchaseorder INTO DATA(ls_purchaseorder).
        APPEND INITIAL LINE TO lr_purchaseorder ASSIGNING FIELD-SYMBOL(<fs_purchaseorder>).
        <fs_purchaseorder>-sign   = 'I'.
        <fs_purchaseorder>-option = 'EQ'.
        <fs_purchaseorder>-low    = |{ ls_purchaseorder-purchaseorder  ALPHA = IN }|. .
      ENDLOOP.
    ENDIF.

    IF ls_request-plant IS NOT INITIAL.
      LOOP AT ls_request-plant INTO DATA(ls_plant).
        APPEND INITIAL LINE TO lr_plant ASSIGNING FIELD-SYMBOL(<fs_plant>).
        <fs_plant>-sign   = 'I'.
        <fs_plant>-option = 'EQ'.
        <fs_plant>-low    = ls_plant-plant.
      ENDLOOP.
    ENDIF.

    "I_Supplier join ile SupplierName eklendi
    SELECT
    serv~purchaseorder AS serviceentrysheet,
    serv~yy1_hakedisadi_pdh as serviceentrysheetname,
    serv~supplier,
    supp~suppliername,
    pohd~purchasecontract AS purchaseorder,      " LOG anahtarı = SÖZLEŞME (Contract). serviceentrysheet = Hakediş(PO).
    poit~plant ,
    pohd~documentcurrency AS interruptioncurrency,
   " SUM( poit~netamount ) AS netpriceamount
    SUM( CASE poit~isreturnsitem WHEN 'X' THEN poit~netamount * -1
                                          ELSE poit~netamount END ) AS netpriceamount
           FROM I_PurchaseOrderAPI01 AS serv
     INNER JOIN I_PurchaseContractAPI01 AS pohd ON
                serv~yy1_purchasecontract_pdh = pohd~purchasecontract
     INNER JOIN i_purchaseorderitemapi01 AS poit ON
                serv~purchaseorder = poit~purchaseorder
     LEFT OUTER JOIN i_supplier AS supp ON
                serv~supplier = supp~supplier
     WHERE serv~purchasingdocumentdeletioncode = ' '
       AND serv~supplier IN @lr_supplier
       AND plant IN @lr_plant
       AND serv~yy1_purchasecontract_pdh IN @lr_purchaseorder
     GROUP BY
     serv~purchaseorder,
     serv~yy1_hakedisadi_pdh,
     serv~supplier,
     supp~suppliername,
     pohd~purchasecontract,
     poit~plant,
     pohd~documentcurrency
     INTO CORRESPONDING FIELDS OF TABLE @lt_response.

    IF lt_response[] IS INITIAL.

    ELSE.
      SELECT *                                "#EC CI_ALL_FIELDS_NEEDED
        FROM  zmmt_inter_log
        FOR ALL ENTRIES IN @lt_response
        WHERE serviceentrysheet EQ @lt_response-serviceentrysheet
        INTO TABLE @DATA(lt_log).                  "#EC CI_NO_TRANSFORM
      IF sy-subrc IS INITIAL.
        LOOP AT lt_response ASSIGNING FIELD-SYMBOL(<fs_response>).
          <fs_response>-interruptionamount = REDUCE zmmd_mmpur_ses_item_netprice( INIT val TYPE zmmd_mmpur_ses_item_netprice
                    FOR wa IN lt_log
                  WHERE ( serviceentrysheet EQ <fs_response>-serviceentrysheet )
                 NEXT val = val + wa-amount ).
          READ TABLE lt_log INTO DATA(ls_l) WITH KEY serviceentrysheet = <fs_response>-serviceentrysheet.
          IF sy-subrc IS INITIAL.
            IF ls_l-statu = '1'.
              <fs_response>-statut = 'İşleniyor'.
            ELSEIF ls_l-statu = '2'.
              <fs_response>-statut = 'Kapatıldı'.
            ENDIF.
          ELSE.
            <fs_response>-statut = 'Yeni'.
          ENDIF.

          "Başındaki sıfırları kaldır
          <fs_response>-serviceentrysheet = |{ <fs_response>-serviceentrysheet ALPHA = OUT }|.
          <fs_response>-supplier = |{ <fs_response>-supplier ALPHA = OUT }|.

        ENDLOOP.
      ENDIF.
    ENDIF.

    /ui2/cl_json=>serialize( EXPORTING data = lt_response pretty_name = /ui2/cl_json=>pretty_mode-camel_case RECEIVING r_json = DATA(lv_res_json) ).
    APPEND INITIAL LINE TO lt_return ASSIGNING FIELD-SYMBOL(<fs_return>).
    <fs_return>-treetable = lv_res_json.
    <fs_return>-filter    = space.
    "RETURN
    io_response->set_data( lt_return ).
    IF io_request->is_total_numb_of_rec_requested(  ).
      io_response->set_total_number_of_records( lines( lt_return ) ).
    ENDIF.
  ENDMETHOD.
ENDCLASS.
