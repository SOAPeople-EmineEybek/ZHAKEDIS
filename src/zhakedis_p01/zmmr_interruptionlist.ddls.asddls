@EndUserText.label: 'List Data'
@Metadata.allowExtensions: true
@ObjectModel.query.implementedBy: 'ABAP:ZCL_MM_INTERRUPTIONLIST'
@UI.headerInfo : { typeName: 'Entity', typeNamePlural: 'Entities'  }
@ObjectModel.resultSet.sizeCategory: #XS
define root custom entity zmmr_Interruptionlist 
{

    key TreeTable : abap.string;
      Filter    : abap.string;
}
