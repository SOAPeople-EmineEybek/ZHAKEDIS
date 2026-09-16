@EndUserText.label: 'Kesinti Türü Bakım Tablosu Singleton'
@AccessControl.authorizationCheck: #NOT_REQUIRED
@ObjectModel.semanticKey: [ 'SingletonID' ]
@UI: {
  headerInfo: {
    typeName: 'ZMMT_INTERTYPE_S'
  }
}
define root view entity ZI_MMT_INTERTYPE_S
  as select from I_Language
    left outer join I_CstmBizConfignLastChgd on I_CstmBizConfignLastChgd.ViewEntityName = 'ZI_MMT_INTERTYPE_D'
  association [0..*] to I_ABAPTransportRequestText as _ABAPTransportRequestText on $projection.TransportRequestID = _ABAPTransportRequestText.TransportRequestID
  composition [0..*] of ZI_MMT_INTERTYPE_D as _ZMMT_INTERTYPE_D
{
  @UI.facet: [ {
    id: 'ZI_MMT_INTERTYPE_D', 
    purpose: #STANDARD, 
    type: #LINEITEM_REFERENCE, 
    label: 'Kesinti Türü Bakım Tablosu', 
    position: 1 , 
    targetElement: '_ZMMT_INTERTYPE_D'
  } ]
  @UI.lineItem: [ {
    position: 1 
  } ]
  key 1 as SingletonID,
  _ZMMT_INTERTYPE_D,
  @UI.hidden: true
  I_CstmBizConfignLastChgd.LastChangedDateTime as LastChangedAtMax,
  @ObjectModel.text.association: '_ABAPTransportRequestText'
  @UI.identification: [ {
    position: 1 , 
    type: #WITH_INTENT_BASED_NAVIGATION, 
    semanticObjectAction: 'manage'
  } ]
  @Consumption.semanticObject: 'CustomizingTransport'
  cast( '' as SXCO_TRANSPORT) as TransportRequestID,
  _ABAPTransportRequestText
}
where I_Language.Language = $session.system_language
