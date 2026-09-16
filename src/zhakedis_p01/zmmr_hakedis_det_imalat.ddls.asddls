@EndUserText.label: 'Hakediş Çıktı Kokpiti (İmalat Detay)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_MM_HAKEDIS_IMALAT_QRY'
@UI.presentationVariant: [{ maxItems: 20 }]
@UI: {
    headerInfo: { typeName: 'İmalat Kalemi', typeNamePlural: 'İmalat Kalemleri' }
}
define custom entity ZMMR_HAKEDIS_DET_IMALAT
{
    @UI.lineItem: [{ position: 10 }]
    key ServiceEntrySheet : mmpur_ses_serviceentrysheet;

    @UI.lineItem: [{ position: 20, label: 'Satınalma Kalemi' }]
    key PurchaseOrderItem : ebelp;

    @UI.lineItem: [{ position: 25, label: 'Harici Mal Grubu' }]
    ExternalProductGroup : abap.char( 18 );

    @UI.lineItem: [{ position: 26, label: 'Harici Mal Grubu Tanımı' }]
    ExternalProductGroupName : abap.char( 40 );

    @UI.lineItem: [{ position: 27, label: 'Mal Grubu' }]
    ProductGroup : abap.char( 9 );

    @UI.lineItem: [{ position: 28, label: 'Mal Grubu Tanımı' }]
    ProductGroupText : abap.char( 40 );

    @UI.lineItem: [{ position: 30, label: 'Poz No' }]
    Material : abap.char( 18 );

    @UI.lineItem: [{ position: 40, label: 'Poz Tanımı' }]
    MaterialText : abap.char( 40 );

    @UI.lineItem: [{ position: 41, label: 'Poz Uzun Tanımı' }]
    MaterialLongText : abap.char( 200 );

    @UI.lineItem: [{ position: 42, label: 'PYP' }]
    WbsElementExternalID : abap.char( 24 );

    @UI.lineItem: [{ position: 43, label: 'PYP Tanımı' }]
    WbsElementText : abap.char( 40 );

    @UI.lineItem: [{ position: 50, label: 'Birim' }]
    OrderQuantityUnit : meins;

    @UI.lineItem: [{ position: 60, label: 'Sözleşme Miktarı' }]
    @Semantics.quantity.unitOfMeasure: 'OrderQuantityUnit'
    OrderQuantity : abap.quan(13,3);

    @Semantics.currencyCode: true
    DocumentCurrency : waers;

    @UI.lineItem: [{ position: 70, label: 'Birim Fiyat' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    NetPriceAmount : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 75, label: 'Sözleşme Kalem Tutarı' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    ContractAmount : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 80, label: 'Önceki Miktar' }]
    @Semantics.quantity.unitOfMeasure: 'OrderQuantityUnit'
    PrevQuantity : abap.quan(13,3);

    @UI.lineItem: [{ position: 90, label: 'Önceki Tutar' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    PrevAmount : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 95, label: 'Önceki %', type: #AS_DATAPOINT }]
    @UI.dataPoint: { qualifier: 'PrevPercent', targetValue: 100, visualization: #PROGRESS }
    PrevPercent : abap.int2;

    @UI.lineItem: [{ position: 100, label: 'Bu Dönem Miktar' }]
    @Semantics.quantity.unitOfMeasure: 'OrderQuantityUnit'
    CurrQuantity : abap.quan(13,3);

    @UI.lineItem: [{ position: 110, label: 'Bu Dönem Tutar' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    CurrAmount : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 115, label: 'Bu Dönem %', type: #AS_DATAPOINT }]
    @UI.dataPoint: { qualifier: 'CurrPercent', targetValue: 100, visualization: #PROGRESS }
    CurrPercent : abap.int2;

    @UI.lineItem: [{ position: 120, label: 'Toplam Miktar' }]
    @Semantics.quantity.unitOfMeasure: 'OrderQuantityUnit'
    TotalQuantity : abap.quan(13,3);

    @UI.lineItem: [{ position: 130, label: 'Toplam Tutar' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    TotalAmount : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 140, label: 'Genel İlerleme %', type: #AS_DATAPOINT }]
    @UI.dataPoint: { qualifier: 'ProgressPercent', targetValue: 100, visualization: #PROGRESS }
    ProgressPercent : abap.int2;
}
