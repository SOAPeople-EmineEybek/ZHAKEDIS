@EndUserText.label: 'TAXCODE  SH'
@Metadata.allowExtensions: true
@ObjectModel.query.implementedBy: 'ABAP:ZCL_MM_SHTAXCODE'
@UI.headerInfo : { typeName: 'Entity', typeNamePlural: 'Entities'  }
@ObjectModel.resultSet.sizeCategory: #XS 
define root custom entity  zmmr_shTAXCODE 
{
 key TaxCode : mwskz;
   TaxCodeName : text50;
   ConditionRateRatio :abap.dec( 5, 2 );
   InterruptionType   : zmmd_interrupt_type_v2;
}
