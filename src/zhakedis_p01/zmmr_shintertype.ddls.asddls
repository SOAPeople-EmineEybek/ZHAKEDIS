@EndUserText.label: 'Inter type SH'
@Metadata.allowExtensions: true
@ObjectModel.query.implementedBy: 'ABAP:ZCL_MM_SHINTERTYPE'
@UI.headerInfo : { typeName: 'Entity', typeNamePlural: 'Entities'  }
@ObjectModel.resultSet.sizeCategory: #XS 
define root custom entity zmmr_shintertype 
{
      key interruptiontype : zmmd_interrupt_type_v2 ;
  interruptiontypetxt  : zmmd_interruptiontypetxt;
}
