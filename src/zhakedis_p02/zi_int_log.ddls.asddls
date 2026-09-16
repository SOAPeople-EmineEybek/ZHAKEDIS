@AccessControl.authorizationCheck: #NOT_ALLOWED
@EndUserText.label: 'Hakediş Rapor BO view'
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZI_INT_LOG
  as select from zmmt_inter_log
{
  key purchaseorder         as Purchaseorder,
  key serviceentrysheet     as Serviceentrysheet,
  key item                  as Item,
      plant                 as Plant,
      interruptioncurrency  as Interruptioncurrency,
      @Semantics.amount.currencyCode: 'Interruptioncurrency'
      netpriceamount        as Netpriceamount,
      statu                 as Statu,
      interruptiontype      as Interruptiontype,
      interruptiontypetext  as Interruptiontypetext,
      @Semantics.amount.currencyCode: 'Interruptioncurrency'
      amount                as Amount,
      taxcode               as Taxcode,
      conditionrateratio    as Conditionrateratio,
      @Semantics.amount.currencyCode: 'Interruptioncurrency'
      amountwithtax         as Amountwithtax,
      note                  as Note,
      local_last_changed_at as LocalLastChangedAt,
      local_last_changed_by as LocalLastChangedBy,
      configdeprecationcode as Configdeprecationcode
}
