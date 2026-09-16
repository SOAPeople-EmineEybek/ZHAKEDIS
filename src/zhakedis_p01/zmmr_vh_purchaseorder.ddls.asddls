@EndUserText.label: 'VH PurchaseOrder Z004'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_VH_PURCHASEORDER'
@ObjectModel.resultSet.sizeCategory: #XS
define custom entity ZMMR_VH_PURCHASEORDER
{
    key PurchaseOrder : ebeln;
        Supplier      : lifnr;
        SupplierName  : abap.char(80);
}
