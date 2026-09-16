@EndUserText.label: 'Hakediş Çıktı Kokpiti (Kesinti Detay)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_MM_HAKEDIS_KESINTI_QRY'
@UI: {
    headerInfo: { typeName: 'Kesinti Detay', typeNamePlural: 'Kesinti Detayları' }
}
define custom entity ZMMR_HAKEDIS_DET_KESINTI
{
    @UI.lineItem: [{ position: 10, label: 'Hakediş No' }]
    key ServiceEntrySheet : mmpur_ses_serviceentrysheet;

    @UI.lineItem: [{ position: 20, label: 'Kesinti Türü' }]
    key InterruptionType : zmmd_interrupt_type_v2;

    @UI.lineItem: [{ position: 25, label: 'Kesinti Para Birimi' }]
    @Semantics.currencyCode: true
    key InterruptionCurrency : waers;

    @UI.lineItem: [{ position: 30, label: 'Kesinti Tanımı' }]
    InterruptionTypeText : zmmd_interruptiontypetxt;

    @UI.lineItem: [{ position: 35, label: 'Fatura Edilecek Mi?' }]
    InvoiceReq : abap.char( 1 );

    @UI.lineItem: [{ position: 36, label: 'Yansıtma' }]
    Reflection : abap.char( 1 );

    @UI.lineItem: [{ position: 40, label: 'Varsayılan Kesinti Oranı (%)' }]
    DefaultInterruptionRate : abap.dec(5,2);

    @UI.lineItem: [{ position: 45, label: 'PYP' }]
    WbsElementText : abap.char( 40 );

    @UI.lineItem: [{ position: 50, label: 'Önceki Kesinti (KDV Hariç)' }]
    @Semantics.amount.currencyCode: 'InterruptionCurrency'
    PrevInterruptionAmount : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 55, label: 'Önceki Kesinti (KDV Dahil)' }]
    @Semantics.amount.currencyCode: 'InterruptionCurrency'
    PrevInterruptionAmountTax : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 60, label: 'Şimdiki Kesinti (KDV Hariç)' }]
    @Semantics.amount.currencyCode: 'InterruptionCurrency'
    CurrInterruptionAmount : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 65, label: 'Şimdiki Kesinti (KDV Dahil)' }]
    @Semantics.amount.currencyCode: 'InterruptionCurrency'
    CurrInterruptionAmountTax : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 70, label: 'Toplam Kesinti (KDV Hariç)' }]
    @Semantics.amount.currencyCode: 'InterruptionCurrency'
    TotalInterruptionAmount : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 75, label: 'Toplam Kesinti (KDV Dahil)' }]
    @Semantics.amount.currencyCode: 'InterruptionCurrency'
    TotalInterruptionAmountTax : zmmd_mmpur_ses_item_netprice;
}
