@EndUserText.label: 'VH Approval Status'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_VH_APPROVAL_STATUS'
define custom entity ZMMR_VH_APPROVAL_STATUS
{
    key StatusCode : abap.char(2);
        StatusText : abap.char(30);
}
