@EndUserText.label: 'VH Interruption Status'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_VH_INT_STATU'
define custom entity ZMMR_VH_INT_STATU
{
    key StatusCode : abap.char(1);
        StatusText : abap.char(30);
}
