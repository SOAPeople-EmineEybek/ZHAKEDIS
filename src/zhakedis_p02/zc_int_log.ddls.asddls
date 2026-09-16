
@EndUserText.label: 'Hakediş Rapor BO projection view'
@AccessControl.authorizationCheck: #NOT_ALLOWED
@Metadata.ignorePropagatedAnnotations: true
@Metadata.allowExtensions: true
define root view entity ZC_INT_LOG as select from ZI_INT_LOG
{
    key Purchaseorder,
    key Serviceentrysheet,
    key Item,
    Plant,
    Interruptioncurrency,
     @Semantics.amount.currencyCode: 'Interruptioncurrency'
    Netpriceamount,
    Statu,
    Interruptiontype,
    Interruptiontypetext,
     @Semantics.amount.currencyCode: 'Interruptioncurrency'
    Amount,
    Taxcode,
    Conditionrateratio,
     @Semantics.amount.currencyCode: 'Interruptioncurrency'
    Amountwithtax,
    Note,
    LocalLastChangedAt,
    LocalLastChangedBy,
    Configdeprecationcode
}
