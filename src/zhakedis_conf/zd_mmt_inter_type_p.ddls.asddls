@EndUserText.label: 'Kesinti Türü Bakım Tablosu kopyala'
define abstract entity ZD_MMT_INTER_TYPE_P
{
  @EndUserText.label: 'Yeni Kesinti Türü'
  @UI.defaultValue: #( 'ELEMENT_OF_REFERENCED_ENTITY: Interruptiontype' )
  Interruptiontype : ZMMD_INTERRUPT_TYPE_V2;
}
