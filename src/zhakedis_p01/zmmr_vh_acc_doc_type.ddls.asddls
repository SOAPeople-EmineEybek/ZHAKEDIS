@EndUserText.label: 'Belge Türü Value Help'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@Metadata.ignorePropagatedAnnotations: true
@ObjectModel.usageType: {
  serviceQuality: #A,
  sizeCategory: #S,
  dataClass: #MASTER
}
@Search.searchable: true
define view entity ZMMR_VH_ACC_DOC_TYPE
  as select from I_AccountingDocumentType
{
      @Search.defaultSearchElement: true
      @ObjectModel.text.element: ['AccountingDocumentTypeName']
  key AccountingDocumentType,

      @Search.defaultSearchElement: true
      @Semantics.text: true
      _Text[ 1: Language = $session.system_language ].AccountingDocumentTypeName as AccountingDocumentTypeName
}
