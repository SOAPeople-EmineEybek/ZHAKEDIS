@EndUserText.label: 'WBS Element SH'
@Metadata.allowExtensions: true
@ObjectModel.query.implementedBy: 'ABAP:ZCL_MM_SHWBS'
@UI.headerInfo : { typeName: 'Entity', typeNamePlural: 'Entities' }
@ObjectModel.resultSet.sizeCategory: #XS
define root custom entity ZMMR_SHWBS
{
  key WbsElement    : abap.char( 24 );
      WbsDescription : abap.char( 40 );
}
