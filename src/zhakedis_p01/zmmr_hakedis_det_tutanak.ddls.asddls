@EndUserText.label: 'Hakediş Çıktı Kokpiti (Tutanak Detay)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_MM_HAKEDIS_TUTANAK_QRY'
@UI: {
    headerInfo: { typeName: 'Tutanak Kalemi', typeNamePlural: 'Tutanak Kalemleri' } 
}
define custom entity ZMMR_HAKEDIS_DET_TUTANAK
{
    @UI.lineItem: [{ position: 10, label: 'Hakediş No' }]
    key ServiceEntrySheet : mmpur_ses_serviceentrysheet;

    @UI.lineItem: [{ position: 20, label: 'Kalem No' }]
    key Item : abap.numc( 5 );

    @UI.lineItem: [{ position: 30, label: 'Kesinti Türü' }]
    InterruptionType : zmmd_interrupt_type_v2;

    @UI.lineItem: [{ position: 40, label: 'Tutanak Tanımı' }]
    InterruptionTypeText : zmmd_interruptiontypetxt;

    @UI.lineItem: [{ position: 50, label: 'PYP' }]
    WbsElement : abap.char( 24 );

    @UI.lineItem: [{ position: 55, label: 'PYP Tanımı' }]
    WbsElementText : abap.char( 40 );

    @Semantics.currencyCode: true
    InterruptionCurrency : waers;

    @UI.lineItem: [{ position: 60, label: 'Net Tutar' }]
    @Semantics.amount.currencyCode: 'InterruptionCurrency'
    NetPriceAmount : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 70, label: 'Tutar' }]
    @Semantics.amount.currencyCode: 'InterruptionCurrency'
    Amount : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 80, label: 'KDV Dahil Tutar' }]
    @Semantics.amount.currencyCode: 'InterruptionCurrency'
    AmountWithTax : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 85, label: 'Fatura Edilecek Mi?' }]
    InvoiceReq : abap.char( 1 );

    @UI.lineItem: [{ position: 86, label: 'Yansıtma' }]
    Reflection : abap.char( 1 );

    @UI.lineItem: [{ position: 90, label: 'Vergi Kodu' }]
    TaxCode : abap.char( 2 );

    @UI.lineItem: [{ position: 95, label: 'Oran (%)' }]
    ConditionRateRatio : abap.dec(5,2);

//    @UI.lineItem: [{ position: 100, label: 'Not' }]
    @UI.hidden: true
    Note : abap.char( 200 );

    @UI.lineItem: [{ position: 100, label: 'Durum' }]
    Status : abap.char( 1 );
}
