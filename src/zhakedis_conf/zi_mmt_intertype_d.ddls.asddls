@EndUserText.label: 'Kesinti Türü Bakım Tablosu'
@AccessControl.authorizationCheck: #MANDATORY
@Metadata.allowExtensions: true
define view entity ZI_MMT_INTERTYPE_D
  as select from ZMMT_INTER_TYPE
  association to parent ZI_MMT_INTERTYPE_S as _ZMMT_INTERTYPE_S on $projection.SingletonID = _ZMMT_INTERTYPE_S.SingletonID
{
  key INTERRUPTIONTYPE as Interruptiontype,
  INTERRUPTIONTYPETXT as Interruptiontypetxt,
  CUSTOM_FIELD as CustomField,
  SIGN_INDICATOR as SignIndicator,
  TAX_ENTRY_REQ as TaxEntryReq,
  INVOICE_REQ as InvoiceReq,
  REFLECTION as Reflection,
  TAXCODE as Taxcode,
  ACC_DOC_TYPE as AccDocType,
  ACC_DOC_TYPE_NEG as AccDocTypeNeg,
  PYP_SUFFIX as PypSuffix,
  WBS_REQ as WbsReq,
  @Consumption.hidden: true
  1 as SingletonID,
  _ZMMT_INTERTYPE_S
}
