@EndUserText.label: 'Plant SH'
@Metadata.allowExtensions: true
@ObjectModel.query.implementedBy: 'ABAP:ZCL_MM_SHPLANT'
@UI.headerInfo : { typeName: 'Entity', typeNamePlural: 'Entities'  }
@ObjectModel.resultSet.sizeCategory: #XS 
define root custom entity zmmr_shPLant
{
  key Plant: werks_d;
      PlantTxt  : text30;
}
 