CLASS zcl_mm_int_gen DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    CLASS-METHODS get_instance
      IMPORTING i_plant    TYPE werks_d OPTIONAL
      EXPORTING r_instance TYPE REF TO zcl_mm_int_gen.
    METHODS constructor
      IMPORTING i_plant TYPE werks_d OPTIONAL.
    METHODS create_int IMPORTING it_item              TYPE zmmtt_int_item
                                 iv_serviceentrysheet TYPE mmpur_ses_serviceentrysheet.
    METHODS close_int  IMPORTING it_serviceentrysheet TYPE zmmtt_int_serviceentrysheet
                       RETURNING VALUE(er_mess)       TYPE string.
    METHODS open_int  IMPORTING it_serviceentrysheet TYPE zmmtt_int_serviceentrysheet
                      RETURNING VALUE(er_mess)       TYPE string.
    METHODS doc_add  IMPORTING iv_serviceentrysheet TYPE mmpur_ses_serviceentrysheet
                     RETURNING VALUE(er_mess)       TYPE string.

    METHODS doc_del  IMPORTING iv_serviceentrysheet TYPE mmpur_ses_serviceentrysheet
                     RETURNING VALUE(er_mess)       TYPE string.

    "! PO'nun silinmemiş ilk kaleminin PYP'sinden 2. noktaya kadarki ön ek (ör. "X5.02.")
    CLASS-METHODS get_pyp_prefix
      IMPORTING iv_purchaseorder TYPE ebeln
      RETURNING VALUE(rv_prefix) TYPE string.

    "! Default PYP = PO ön eki ++ kesinti türünün "PYP son eki"
    CLASS-METHODS get_default_pyp
      IMPORTING iv_purchaseorder    TYPE ebeln
                iv_interruptiontype TYPE zmmd_interrupt_type_v2
      RETURNING VALUE(rv_pyp)       TYPE string.
  PROTECTED SECTION.
  PRIVATE SECTION.

    CLASS-DATA : instance     TYPE REF TO zcl_mm_int_gen.
    DATA : BEGIN OF gs_key,
             plant TYPE werks_d,
           END OF gs_key.

ENDCLASS.



CLASS ZCL_MM_INT_GEN IMPLEMENTATION.

  METHOD get_pyp_prefix.
    " 1) PO'nun silinmemiş ilk kalemi (en küçük kalem no)
    SELECT purchaseorderitem
      FROM i_purchaseorderitemapi01
      WHERE purchaseorder = @iv_purchaseorder
        AND purchasingdocumentdeletioncode = ' '
      ORDER BY purchaseorderitem
      INTO @DATA(lv_item)
      UP TO 1 ROWS.                                      "#EC CI_NOAUTH
    ENDSELECT.
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " 2) Hesap atamasından WBSElementInternalID (birden fazla olabilir, herhangi biri)
    SELECT SINGLE wbselementinternalid_2
      FROM i_purordaccountassignmentapi01
      WHERE purchaseorder          = @iv_purchaseorder
        AND purchaseorderitem      = @lv_item
        AND wbselementinternalid_2 IS NOT INITIAL
      INTO @DATA(lv_wbsint).                             "#EC CI_NOAUTH
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " 3) Internal ID -> ProjectElement (PYP)
    SELECT SINGLE projectelement
      FROM i_enterpriseprojectelement
      WHERE wbselementinternalid = @lv_wbsint
      INTO @DATA(lv_projelem).                           "#EC CI_NOAUTH
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    " 4) 2. nokta ve öncesini al: "X5.02.08.003" -> "X5.02."
    DATA(lv_str)    = CONV string( lv_projelem ).
    DATA(lv_second) = find( val = lv_str sub = `.` occ = 2 ).
    IF lv_second < 0.
      RETURN.
    ENDIF.
    rv_prefix = substring( val = lv_str off = 0 len = lv_second + 1 ).
  ENDMETHOD.


  METHOD get_default_pyp.
    DATA(lv_prefix) = get_pyp_prefix( iv_purchaseorder ).
    IF lv_prefix IS INITIAL.
      RETURN.
    ENDIF.

    SELECT SINGLE pyp_suffix
      FROM zmmt_inter_type
      WHERE interruptiontype = @iv_interruptiontype
      INTO @DATA(lv_suffix).             "#EC CI_NOAUTH "#EC CI_NOORDER
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    rv_pyp = |{ lv_prefix }{ condense( CONV string( lv_suffix ) ) }|.
  ENDMETHOD.


  METHOD close_int.
    LOOP AT it_serviceentrysheet INTO DATA(ls_i).
      DATA(lv_ses) = CONV mmpur_ses_serviceentrysheet( |{ ls_i-serviceentrysheet ALPHA = IN }| ).
      UPDATE zmmt_inter_log SET statu = '2' WHERE serviceentrysheet = @lv_ses.
      COMMIT WORK.
      doc_add(
            EXPORTING
              iv_serviceentrysheet = lv_ses
            RECEIVING
              er_mess              = DATA(lv_mess)
          ).
    ENDLOOP.
    er_mess = 'Kayıtlar Kapatıldı'.
  ENDMETHOD.


  METHOD constructor.
    CLEAR: gs_key.
    gs_key-plant = i_plant.
  ENDMETHOD.


  METHOD create_int.
    DELETE FROM zmmt_inter_log WHERE serviceentrysheet = @iv_serviceentrysheet.
    COMMIT WORK.
    MODIFY zmmt_inter_log FROM TABLE @it_item.
    COMMIT WORK.

  ENDMETHOD.


  METHOD doc_add.
    DATA: lv_attachmentobjectkey TYPE if_attachment_service_api=>objectkey,
          lv_technicalobjecttype TYPE if_attachment_service_api=>technicalobjecttype,
          attachment_service     TYPE REF TO if_attachment_service_api,
          media_resource         TYPE if_attachment_service_api=>ty_s_media_resource,
          error                  TYPE REF TO cx_attachment_service,
          text                   TYPE string,
          lv_filename            TYPE if_attachment_service_api=>filename.

*---------------------------------------------------------------------*
* 1) Excel’e yazılacak yapı
*---------------------------------------------------------------------*
    TYPES: BEGIN OF ty_row,
             purchaseorder        TYPE zmmt_inter_log-purchaseorder,
             serviceentrysheet    TYPE zmmt_inter_log-serviceentrysheet,
             item                 TYPE zmmt_inter_log-item,
             plant                TYPE zmmt_inter_log-plant,
             interruptioncurrency TYPE zmmt_inter_log-interruptioncurrency,
             netpriceamount       TYPE zmmt_inter_log-netpriceamount,
             statu                TYPE zmmt_inter_log-statu,
             interruptiontype     TYPE zmmt_inter_log-interruptiontype,
             interruptiontypetext TYPE zmmt_inter_log-interruptiontypetext,
           END OF ty_row.

    DATA: it_table TYPE STANDARD TABLE OF ty_row WITH EMPTY KEY,
          it_data  TYPE STANDARD TABLE OF zmmt_inter_log.

*---------------------------------------------------------------------*
* 2) Veri çekme
*---------------------------------------------------------------------*
    SELECT purchaseorder,
           serviceentrysheet,
           item,
           plant,
           interruptioncurrency,
           netpriceamount,
           statu,
           interruptiontype,
           interruptiontypetext
      FROM zmmt_inter_log
      WHERE serviceentrysheet EQ @iv_serviceentrysheet
      INTO CORRESPONDING FIELDS OF TABLE @it_data.

    MOVE-CORRESPONDING it_data TO it_table.

*---------------------------------------------------------------------*
* 3) Boş XLSX oluştur
*---------------------------------------------------------------------*
    DATA(lo_write_access) = xco_cp_xlsx=>document->empty( )->write_access( ).
    DATA(lo_worksheet)    = lo_write_access->get_workbook( )->worksheet->at_position( 1 ).

*---------------------------------------------------------------------*
* 4) Başlıkları Yaz (1. Satır)
*---------------------------------------------------------------------*
    DATA(lo_cursor) = lo_worksheet->cursor(
      io_column = xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' )
      io_row    = xco_cp_xlsx=>coordinate->for_numeric_value( 1 )
    ).

    lo_cursor->get_cell( )->value->write_from( 'Satınalma Siparişi' ).
    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Hizmet Giriş Fişi' ).
    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Kalem' ).
    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Üretim Yeri' ).
    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Para Birimi' ).
    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Net Tutar' ).
    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Durum' ).
    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Kesinti Türü' ).
    lo_cursor->move_right( )->get_cell( )->value->write_from( 'Kesinti Türü Açıklaması' ).

*---------------------------------------------------------------------*
* 5) A2’den itibaren verileri yaz
*---------------------------------------------------------------------*
    DATA(lo_selection_pattern) =
      xco_cp_xlsx_selection=>pattern_builder->simple_from_to( )->from_column( xco_cp_xlsx=>coordinate->for_alphabetic_value( 'A' ) )->from_row( xco_cp_xlsx=>coordinate->for_numeric_value( 2 ) )->get_pattern( ).

    lo_worksheet->select( lo_selection_pattern )->row_stream( )->operation->write_from( REF #( it_table ) )->set_value_transformation(
           xco_cp_xlsx_write_access=>value_transformation->best_effort )->execute( ).

*---------------------------------------------------------------------*
* 6) XLSX’i XSTRING olarak al
*---------------------------------------------------------------------*
    DATA(lv_file_content_xstr) = lo_write_access->get_file_content( ).

*---------------------------------------------------------------------*
* 7) Media Resource oluştur
*---------------------------------------------------------------------*
    media_resource = VALUE #(
      mime_type = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
      value     = lv_file_content_xstr ).

*---------------------------------------------------------------------*
* 8) Attachment oluştur
*---------------------------------------------------------------------*
    attachment_service = cl_attachment_service_api=>get_instance( ).

    lv_technicalobjecttype = 'MMPUR_SES'.
    lv_attachmentobjectkey = iv_serviceentrysheet.
    lv_filename = |Hakedis_{ iv_serviceentrysheet }.xlsx|.

    TRY.
        attachment_service->create_attachment(
          EXPORTING
            iv_technicalobjecttype = lv_technicalobjecttype
            iv_attachmentobjectkey = lv_attachmentobjectkey
            iv_filename            = lv_filename
            iv_documenttype        = 'SL1'
            is_media_resource      = media_resource
          IMPORTING
            es_attachment          = DATA(ls_attachment) ).

        COMMIT WORK.


      CATCH cx_attachment_service INTO error.
        text = error->get_longtext( ).
    ENDTRY.


    SELECT *                                  "#EC CI_ALL_FIELDS_NEEDED
  FROM i_journalentry
  WHERE accountingdocument EQ @iv_serviceentrysheet
  INTO TABLE @DATA(lt_data).


    SELECT *                                  "#EC CI_ALL_FIELDS_NEEDED
    FROM C_PurchaseOrderDEX
    WHERE purchaseorder EQ @iv_serviceentrysheet
    INTO TABLE @DATA(lt_data1).

  ENDMETHOD.


  METHOD doc_del.

    DATA: attachment_service TYPE REF TO if_attachment_service_api,
*          lt_attachments     TYPE if_attachment_service_api=>ty_t_attachment,
*          ls_attachment      TYPE if_attachment_service_api=>ty_s_attachment,
          lv_success         TYPE abap_bool,
*          lt_messages        TYPE if_attachment_service_api=>ty_t_message,
          error              TYPE REF TO cx_attachment_service,
          text               TYPE string,
          lv_filename        TYPE if_attachment_service_api=>filename..

    DATA: lv_technicalobjecttype TYPE if_attachment_service_api=>technicalobjecttype,
          lv_attachmentobjectkey TYPE if_attachment_service_api=>objectkey.
    lv_filename = |Hakedis_{ iv_serviceentrysheet }.xlsx|.
    lv_technicalobjecttype = 'MMPUR_SES'.
    lv_attachmentobjectkey = iv_serviceentrysheet.

    attachment_service = cl_attachment_service_api=>get_instance( ).

*---------------------------------------------------------------------*
* 1) Önce attachment listesini al
*---------------------------------------------------------------------*
    TRY.
        attachment_service->get_list_of_attachments(
          EXPORTING
            iv_technicalobjecttype = lv_technicalobjecttype
            iv_attachmentobjectkey = lv_attachmentobjectkey
          IMPORTING
            et_attachments         = DATA(lt_attachments) ).

      CATCH cx_attachment_service INTO error.
        text = error->get_longtext( ).
        RETURN.
    ENDTRY.

**---------------------------------------------------------------------*
** 2) Sadece Hakedis_ ile başlayanları sil
**---------------------------------------------------------------------*
    LOOP AT lt_attachments INTO DATA(ls_attachment) WHERE filename = lv_filename.
*
**  IF ls_attachment-filename CP 'Hakedis_*'.
*
      TRY.
          attachment_service->delete_attachment(
            EXPORTING
              iv_logicaldocument     = ls_attachment-logicaldocument
              iv_archivedocumentid   = ls_attachment-archivedocumentid
              iv_technicalobjecttype = ls_attachment-technicalobjecttype
              iv_attachmentobjectkey = ls_attachment-attachmentobjectkey
            IMPORTING
              ev_success             = lv_success
              et_messages            = DATA(lt_messages) ).

        CATCH cx_attachment_service INTO error.
          text = error->get_longtext( ).
      ENDTRY.
*
**  ENDIF.
*
    ENDLOOP.
*
    COMMIT WORK.

  ENDMETHOD.


  METHOD get_instance.

    IF instance IS NOT BOUND.
      instance = NEW #( i_plant = i_plant ).
    ENDIF.
    r_instance = instance.
  ENDMETHOD.


  METHOD open_int.
    LOOP AT it_serviceentrysheet INTO DATA(ls_i).
      DATA(lv_ses) = CONV mmpur_ses_serviceentrysheet( |{ ls_i-serviceentrysheet ALPHA = IN }| ).
      UPDATE zmmt_inter_log SET statu = '1' WHERE serviceentrysheet = @lv_ses.
      COMMIT WORK.
      doc_del(
        EXPORTING
          iv_serviceentrysheet = lv_ses
        RECEIVING
          er_mess              = DATA(lv_mess)
      ).
    ENDLOOP.
    er_mess = 'Kayıtlar Açıldı'.
  ENDMETHOD.
ENDCLASS.
