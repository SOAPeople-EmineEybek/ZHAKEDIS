@EndUserText.label: 'Supplier SH'
@Metadata.allowExtensions: true
@ObjectModel.query.implementedBy: 'ABAP:ZCL_MM_SHSUPPLIER'
@UI.headerInfo : { typeName: 'Entity', typeNamePlural: 'Entities'  }
@ObjectModel.resultSet.sizeCategory: #XS 
define root custom entity  zmmr_SHsupplier 
{
      key Supplier         : lifnr;
  SupplierFullname : zmmd_supplierfullname;
}
