@EndUserText.label: 'Hakediş Kaydet'
@Metadata.allowExtensions: true
@ObjectModel.query.implementedBy: 'ABAP:ZCL_MM_SETINTTABLE'
@UI.headerInfo : { typeName: 'Entity', typeNamePlural: 'Entities'  }
@ObjectModel.resultSet.sizeCategory: #XS
define root custom entity ZMMR_INT_SETTABLE 
{
      key TreeTable : abap.string;
      Filter    : abap.string;
      evjson    : abap.string(0);
      status    : zmmd_intstatu;
      statust   : char20;
           Amount    : abap.string(0);
     
}
