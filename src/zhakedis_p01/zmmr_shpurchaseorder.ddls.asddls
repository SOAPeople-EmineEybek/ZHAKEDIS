@EndUserText.label: 'Purchaseorderr SH'
@Metadata.allowExtensions: true
@ObjectModel.query.implementedBy: 'ABAP:ZCL_MM_SHPURCHASEORDER'
@UI.headerInfo : { typeName: 'Entity', typeNamePlural: 'Entities'  }
@ObjectModel.resultSet.sizeCategory: #XS 
define root custom entity  zmmr_SHpurchaseorder
{
      key   PurchaseOrder : ebeln;
}
