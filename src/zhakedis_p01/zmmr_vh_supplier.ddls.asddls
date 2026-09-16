@EndUserText.label: 'VH Supplier'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_VH_SUPPLIER'
@ObjectModel.resultSet.sizeCategory: #XS
define custom entity ZMMR_VH_SUPPLIER
{
    key Supplier     : lifnr;
        SupplierName : abap.char(80);
}
