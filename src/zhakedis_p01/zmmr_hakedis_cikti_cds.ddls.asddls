@EndUserText.label: 'Hakediş Çıktı Kokpiti (Ana Ekran)'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_MM_HAKEDIS_CIKTI_QRY'
@UI: {
    headerInfo: { typeName: 'Hakediş', typeNamePlural: 'Hakediş Listesi', title: { type: #STANDARD, value: 'ServiceEntrySheet' } }
}
define root custom entity ZMMR_HAKEDIS_CIKTI_CDS
{
    @UI.lineItem: [{ position: 10, label: 'Hakediş No' }]
    @UI.selectionField: [{ position: 10 }]
    key ServiceEntrySheet : mmpur_ses_serviceentrysheet;

    @UI.lineItem: [{ position: 20, label: 'Sözleşme No' }]
    @UI.selectionField: [{ position: 20 }]
    PurchaseOrder : ebeln;

    @UI.lineItem: [{ position: 30, label: 'Sözleşme Tipi' }]
    @UI.selectionField: [{ position: 50 }]
    PurchaseOrderType : abap.char( 4 );

    @UI.lineItem: [{ position: 40, label: 'Sözleşme Tipi Tanımı' }]
    PurchaseOrderTypeTxt : abap.char( 25 );

    @UI.lineItem: [{ position: 50, label: 'Ana Grup' }]
    @UI.selectionField: [{ position: 60 }]
    YY1_AnaGrup_PDH : abap.char( 20 );

    @UI.lineItem: [{ position: 60, label: 'Ana Grup Tanımı' }]
    YY1_AnaGrup_PDHT : abap.char( 40 );

    @UI.lineItem: [{ position: 70, label: 'Sözleşme Tarihi' }]
    PurchaseOrderDate : abap.dats;

    @UI.lineItem: [{ position: 80, label: 'Sözleşme Bşl. Tarihi' }]
    YY1_SozBasTar : abap.dats;

    @UI.lineItem: [{ position: 90, label: 'Sözleşme Bitiş Tarihi' }]
    YY1_SozBitTar : abap.dats;

    @UI.lineItem: [{ position: 100, label: 'Tedarikçi No' }]
    @UI.selectionField: [{ position: 30 }]
    Supplier : lifnr;

    @UI.lineItem: [{ position: 110, label: 'Tedarikçi Adı' }]
    SupplierName : zmmd_supplierfullname;

    @UI.lineItem: [{ position: 120, label: 'Şirket Kodu' }]
    @UI.selectionField: [{ position: 40 }]
    CompanyCode : bukrs;

    @UI.lineItem: [{ position: 130, label: 'Şirket Kodu Tanımı' }]
    CompanyCodeName : abap.char( 25 );

    @UI.lineItem: [{ position: 140, label: 'Hakediş Adı' }]
    ServiceEntrySheetName : zmmd_mmpur_ses_ses_name;

    @UI.lineItem: [{ position: 150, label: 'Düzenlenme Tarihi' }]
    @UI.selectionField: [{ position: 70 }]
    CreationDate : abap.dats;

    @UI.lineItem: [{ position: 160, label: 'Kayıt Tarihi' }]
    @UI.selectionField: [{ position: 80 }]
    PostingDate : abap.dats;

    @UI.hidden: true
    ApprovalStatus : abap.char( 2 );
    @UI.lineItem: [{ position: 170, label: 'Hakediş Onay Durumu', criticality: 'ApprovalStatusCriticality' }]
    @UI.selectionField: [{ position: 90 }]
    ApprovalStatusText : abap.char( 30 );
    @UI.hidden: true
    ApprovalStatusCriticality : abap.int1;

    @UI.hidden: true
    IntStatu : zmmd_intstatu;
    @UI.lineItem: [{ position: 180, label: 'Kesinti Giriş Durumu', criticality: 'IntStatuCriticality' }]
    @UI.selectionField: [{ position: 100 }]
    IntStatuText : abap.char( 30 );
    @UI.hidden: true
    IntStatuCriticality : abap.int1;

    @Semantics.currencyCode: true
    DocumentCurrency : waers;

    @UI.lineItem: [{ position: 190, label: 'Toplam Sözleşme Tutarı' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    TotalContractAmount : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 200, label: 'Hakediş Tutarı' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    SesAmount : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 205, label: 'Tutanak Tutarı' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    TutanakAmount : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 210, label: 'Kesinti Tutarı' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    TotalInterruptionAmount : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 215, label: 'Ödenecek Tutar' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    OdenecekTutar : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 220, label: 'Önceki Hakediş İmalat Toplamı' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    PrevSesTotal : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 225, label: 'Toplam Hakediş İmalat Tutarı' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    GrandSesTotal : zmmd_mmpur_ses_item_netprice;

    @UI.hidden: true
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    AllDeductionTotal : zmmd_mmpur_ses_item_netprice;

    // ===== KDV DAHİL karşılıklar ("Tutar Bilgileri (KDV Dahil)" header bloğu) =====
    // Log-tabanlılar (Tutanak, Kesinti): GERÇEK dahil tutarı (amountwithtax).
    // İmalat/Sözleşme dahil'i: PO/sözleşme kalem vergi kodu → I_TaxCodeRate oranı ile hesaplanır
    // (kesinti giriş değer yardımı ZCL_MM_SHTAXCODE ile aynı kaynak).
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    TotalContractAmountTax : zmmd_mmpur_ses_item_netprice;

    @Semantics.amount.currencyCode: 'DocumentCurrency'
    SesAmountTax : zmmd_mmpur_ses_item_netprice;

    @Semantics.amount.currencyCode: 'DocumentCurrency'
    TutanakAmountTax : zmmd_mmpur_ses_item_netprice;

    @Semantics.amount.currencyCode: 'DocumentCurrency'
    TotalInterruptionAmountTax : zmmd_mmpur_ses_item_netprice;

    @Semantics.amount.currencyCode: 'DocumentCurrency'
    OdenecekTutarTax : zmmd_mmpur_ses_item_netprice;

    @Semantics.amount.currencyCode: 'DocumentCurrency'
    PrevSesTotalTax : zmmd_mmpur_ses_item_netprice;

    @Semantics.amount.currencyCode: 'DocumentCurrency'
    GrandSesTotalTax : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 301, label: 'Avans Mahsubu (İşveren)' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    IntK01 : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 302, label: 'Avans Mahsubu (Yüklenici)' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    IntK02 : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 303, label: 'Kesin Teminat' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    IntK03 : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 304, label: 'Nakit Teminat' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    IntK04 : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 305, label: 'Arabuluculuk Teminatı' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    IntK05 : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 306, label: 'Stopaj' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    IntK06 : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 307, label: 'KDV Tevkifatı' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    IntK07 : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 308, label: 'All Risk Sigortası' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    IntK08 : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 309, label: 'Su Bedeli' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    IntK09 : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 310, label: 'Elektrik Bedeli' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    IntK10 : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 311, label: 'Gecikme Cezası' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    IntK11 : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 312, label: 'Malzeme Bedeli' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    IntK12 : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 313, label: 'Kamp Koğuş Bedeli' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    IntK13 : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 314, label: 'Temizlik Bedeli' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    IntK14 : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 315, label: 'Çöp-Moloz Bedeli' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    IntK15 : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 316, label: 'İşçilik Bedeli' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    IntK16 : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 317, label: 'Ekipman vs. Kira Bedeli' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    IntK17 : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 318, label: 'İş Güvenliği Cezası' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    IntK18 : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 319, label: 'Yemek Bedeli' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    IntK19 : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 320, label: 'Farklı Yüklenici Yansıtması' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    IntK20 : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 321, label: 'İş Güvenliği Gözlem Bedeli' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    IntK21 : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 322, label: 'Uygunsuz İmalat Bedeli' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    IntK22 : zmmd_mmpur_ses_item_netprice;

    @UI.lineItem: [{ position: 323, label: 'Nefaset' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    IntK23 : zmmd_mmpur_ses_item_netprice;
    
    @UI.lineItem: [{ position: 323, label: 'Doğalgaz Bedeli' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    IntK24 : zmmd_mmpur_ses_item_netprice;
    
    @UI.lineItem: [{ position: 323, label: 'Damga Vergisi' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    IntK25 : zmmd_mmpur_ses_item_netprice;
    
    @UI.lineItem: [{ position: 323, label: 'Diğer Ödemeler' }]
    @Semantics.amount.currencyCode: 'DocumentCurrency'
    IntK26 : zmmd_mmpur_ses_item_netprice;
}
