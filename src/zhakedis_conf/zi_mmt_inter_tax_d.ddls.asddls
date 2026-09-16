@EndUserText.label: 'Kesinti Türü - Kullanılabilir Vergi Türü'
@AccessControl.authorizationCheck: #MANDATORY
@Metadata.allowExtensions: true
define view entity ZI_MMT_INTER_TAX_D
  as select from ZMMT_INTER_TAX
  association to parent ZI_MMT_INTER_TAX_S as _ZMMT_INTER_TAX_S on $projection.SingletonID = _ZMMT_INTER_TAX_S.SingletonID
{
  key INTERRUPTIONTYPE as Interruptiontype,
  key TAXCODE as Taxcode,
  @Consumption.hidden: true
  1 as SingletonID,
  _ZMMT_INTER_TAX_S
}
