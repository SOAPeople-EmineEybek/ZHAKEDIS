@EndUserText.label: 'VH CompanyCode'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_VH_COMPANYCODE'
@ObjectModel.resultSet.sizeCategory: #XS
define custom entity ZMMR_VH_COMPANYCODE
{
    key CompanyCode     : bukrs;
        CompanyCodeName : abap.char(25);
}
