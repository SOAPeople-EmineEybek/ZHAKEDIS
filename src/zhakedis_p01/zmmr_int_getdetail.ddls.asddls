@EndUserText.label: 'Int Detail'
@Metadata.allowExtensions: true
@ObjectModel.query.implementedBy: 'ABAP:ZCL_MM_INTGETDETAIL'
@UI.headerInfo : { typeName: 'Entity', typeNamePlural: 'Entities'  }
@ObjectModel.resultSet.sizeCategory: #XS
define root custom entity ZMMR_INT_GETDETAIL
{
  key TreeTable : abap.string;
      Filter    : abap.string;
      Evjson    : abap.string(0);
      Status    : zmmd_intstatu;
      Statust   : char20;
      Active    : xfeld;
      PypPrefix : zmmd_pyp_son_ek;
   
}
