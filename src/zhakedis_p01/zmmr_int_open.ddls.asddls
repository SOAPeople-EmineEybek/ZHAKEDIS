@EndUserText.label: 'Hakediş kapatma'
@Metadata.allowExtensions: true
@ObjectModel.query.implementedBy: 'ABAP:ZCL_MM_INT_OPEN'
@UI.headerInfo : { typeName: 'Entity', typeNamePlural: 'Entities'  }
@ObjectModel.resultSet.sizeCategory: #XS
define root custom entity  ZMMR_INT_open
{
      key TreeTable : abap.string;
      Filter    : abap.string;
}
